# =============================================================================
# GKE Cluster - Single Cluster for Infrastructure + Analytics
# =============================================================================
# This Terraform configuration creates ONLY GCP resources:
# - GKE cluster (zonal)
# - Node pool with autoscaling
# - Static IP for ingress
#
# Infrastructure (cert-manager, ingress-nginx) and Analytics (edge-analytics)
# are deployed via Helm in separate namespaces.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# =============================================================================
# GKE Cluster - Zonal (Cheapest Option)
# =============================================================================

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone # Zonal cluster (cheaper than regional)
  project  = var.project_id

  # We manage node pools separately for more control
  remove_default_node_pool = true
  initial_node_count       = 1

  # Cheapest networking options
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}

  # Disable expensive add-ons
  addons_config {
    http_load_balancing {
      disabled = false # Keep for ingress
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    # Disable expensive features
    gcp_filestore_csi_driver_config {
      enabled = false
    }
    gcs_fuse_csi_driver_config {
      enabled = false
    }
  }

  # Release channel for auto-updates (reduces maintenance cost)
  release_channel {
    channel = "STABLE"
  }

  # Workload identity (free, secure)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Maintenance window (during off-hours)
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Logging/monitoring - use free tier
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = false # Use our own Prometheus via Helm
    }
  }

  # Private cluster for security (optional)
  dynamic "private_cluster_config" {
    for_each = var.enable_private_nodes ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = false
      master_ipv4_cidr_block  = "172.16.0.0/28"
    }
  }

  # Binary authorization disabled (cost)
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  deletion_protection = false

  lifecycle {
    ignore_changes = [
      node_config,
    ]
  }
}

# =============================================================================
# Node Pool - Spot VMs (Cheapest)
# =============================================================================

resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.cluster_name}-node-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  # Autoscaling for cost optimization
  autoscaling {
    min_node_count  = var.min_node_count
    max_node_count  = var.max_node_count
    location_policy = "ANY" # Allows spot VMs from any zone
  }

  # Start with minimum nodes
  initial_node_count = var.min_node_count

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    # Cheapest machine type for edge workloads
    machine_type = var.machine_type

    # SPOT VMs - up to 91% cheaper!
    spot = var.use_spot_vms

    # Minimal disk
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard" # Cheapest disk type

    # Container-Optimized OS (free)
    image_type = "COS_CONTAINERD"

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Labels
    labels = {
      env     = var.environment
      cluster = var.cluster_name
    }

    # Taints for spot VMs (optional)
    dynamic "taint" {
      for_each = var.use_spot_vms ? [1] : []
      content {
        key    = "cloud.google.com/gke-spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    }

    # Shielded instance (free security feature)
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}

# =============================================================================
# Static IP for Ingress (nip.io)
# =============================================================================

resource "google_compute_address" "ingress_ip" {
  name         = "${var.cluster_name}-ingress-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD" # Cheaper than PREMIUM
}

# =============================================================================
# Outputs
# =============================================================================

output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location (zone)"
  value       = google_container_cluster.primary.location
}

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "zone" {
  description = "GCP zone"
  value       = var.zone
}

output "ingress_ip" {
  description = "Static IP for ingress (use with nip.io)"
  value       = google_compute_address.ingress_ip.address
}

output "nip_io_domain" {
  description = "nip.io wildcard domain for services"
  value       = "${google_compute_address.ingress_ip.address}.nip.io"
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}"
}
