# =============================================================================
# Variables - GKE Cluster Configuration
# =============================================================================

variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "data-cluster-gke1"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"  # Usually cheapest
}

variable "zone" {
  description = "GCP zone for zonal cluster (cheapest option)"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "edge-analytics"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# =============================================================================
# Node Pool Configuration (Cost Optimization)
# =============================================================================

variable "machine_type" {
  description = "Machine type for nodes (e2-medium is cheapest balanced option)"
  type        = string
  default     = "e2-medium"  # 2 vCPU, 4GB RAM - ~$24/month (standard)
  # Alternatives:
  # - e2-small: 2 vCPU, 2GB RAM - ~$12/month (very tight for edge workloads)
  # - e2-standard-2: 2 vCPU, 8GB RAM - ~$48/month (more memory)
  # - n2d-standard-2: 2 vCPU, 8GB RAM - AMD, slightly cheaper
}

variable "min_node_count" {
  description = "Minimum number of nodes (set to 1 for cheapest)"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 3
}

variable "disk_size_gb" {
  description = "Disk size for nodes in GB"
  type        = number
  default     = 50  # Minimum for edge workloads
}

variable "use_spot_vms" {
  description = "Use Spot VMs (up to 91% cheaper, but can be preempted)"
  type        = bool
  default     = true  # Recommended for dev/non-critical workloads
}

variable "enable_private_nodes" {
  description = "Enable private nodes (more secure, same cost)"
  type        = bool
  default     = false  # Set to true for production
}

# =============================================================================
# cert-manager Configuration
# =============================================================================

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.13.3"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
  default     = "admin@example.com"
}

variable "letsencrypt_server" {
  description = "Let's Encrypt server (staging for testing, production for real certs)"
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
  # Staging: https://acme-staging-v02.api.letsencrypt.org/directory
}

# =============================================================================
# Ingress Configuration
# =============================================================================

variable "ingress_nginx_version" {
  description = "ingress-nginx Helm chart version"
  type        = string
  default     = "4.9.0"
}
