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
  default     = "europe-central2"
}

variable "zone" {
  description = "GCP zone for zonal cluster (cheapest option)"
  type        = string
  default     = "europe-central2-b"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "edge-analytics"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# =============================================================================
# Node Pool Configuration (Cost Optimization)
# =============================================================================

variable "machine_type" {
  description = "Machine type for nodes (e2-medium is cheapest balanced option)"
  type        = string
  default     = "e2-medium" # 2 vCPU, 4GB RAM - ~$24/month (standard)
  # Alternatives:
  # - e2-small: 2 vCPU, 2GB RAM - ~$12/month (very tight for edge workloads)
  # - e2-standard-2: 2 vCPU, 8GB RAM - ~$48/month (more memory)
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
  default     = 50 # Minimum for edge workloads
}

variable "use_spot_vms" {
  description = "Use Spot VMs (up to 91% cheaper, but can be preempted)"
  type        = bool
  default     = true # Recommended for dev/non-critical workloads
}

variable "enable_private_nodes" {
  description = "Enable private nodes (more secure, same cost)"
  type        = bool
  default     = false # Set to true for production
}
