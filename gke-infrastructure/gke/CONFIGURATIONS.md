# Terraform Configuration Examples

This directory contains example Terraform configurations for different deployment scenarios.

## Quick Start

```bash
# Choose a configuration based on your needs
cp terraform.tfvars.balanced terraform.tfvars  # RECOMMENDED

# Edit with your project ID
vim terraform.tfvars

# Deploy
terraform init
terraform apply
```

## Available Configurations

### terraform.tfvars.minimal
**Machine Type**: e2-standard-2 (2 vCPU, 8 GB RAM)  
**Cost**: ~$25-50/month with Spot VMs  
**Supports**:
- ✅ Infrastructure (cert-manager, ingress-nginx)
- ✅ Artemis MQTT
- ✅ ClickHouse
- ✅ Redis
- ❌ NiFi (not enough resources)
- ❌ Dagster (not enough resources)

**Use for**: Testing, development, minimal MQTT + database setup

### terraform.tfvars.balanced (RECOMMENDED)
**Machine Type**: e2-standard-4 (4 vCPU, 16 GB RAM)  
**Cost**: ~$50-150/month with Spot VMs  
**Supports**:
- ✅ All infrastructure components
- ✅ All analytics components
- ✅ Artemis MQTT
- ✅ ClickHouse
- ✅ Apache NiFi
- ✅ Redis
- ✅ Dagster
- ✅ Prometheus
- ✅ Grafana
- ✅ Dashboard API

**Use for**: Full analytics stack, staging, production (with Spot VMs for cost savings)

### terraform.tfvars.production
**Machine Type**: e2-standard-4 (4 vCPU, 16 GB RAM)  
**Min Nodes**: 2 (for HA)  
**Spot VMs**: Disabled (for reliability)  
**Cost**: ~$200-500/month  
**Supports**:
- ✅ All components
- ✅ High availability
- ✅ Private nodes (enhanced security)
- ✅ No Spot VMs (stable)

**Use for**: Production workloads requiring HA and reliability

## Resource Requirements Summary

| Component | CPU (request) | RAM (request) |
|-----------|---------------|---------------|
| cert-manager | 100m | 160Mi |
| ingress-nginx | 100m | 128Mi |
| Artemis MQTT | 250m | 512Mi |
| ClickHouse | 500m | 1Gi |
| Apache NiFi | 500m | 1Gi |
| Zookeeper | 100m | 256Mi |
| Redis | 100m | 128Mi |
| Dagster | 350m | 768Mi |
| Prometheus | 500m | 512Mi |
| Grafana | 100m | 128Mi |
| Dashboard API | 100m | 128Mi |
| **GKE Overhead** | 300m | 700Mi |
| **Total (All)** | ~3 CPU | ~5.5 GB |

See [docs/RESOURCE_REQUIREMENTS.md](../../docs/RESOURCE_REQUIREMENTS.md) for detailed calculations.

## Customization

Edit any terraform.tfvars file to customize:

```hcl
# Your GCP project
project_id = "your-project-id"

# Location
region = "europe-central2"
zone   = "europe-central2-b"

# Cluster settings
cluster_name = "my-cluster"
environment  = "production"

# Node pool
machine_type   = "e2-standard-4"
min_node_count = 1
max_node_count = 3
disk_size_gb   = 100
use_spot_vms   = true

# Security
enable_private_nodes = false
```

## Cost Optimization Tips

1. **Use Spot VMs**: 60-91% cheaper than standard VMs
2. **Start small**: Use `min_node_count = 1` and let it autoscale
3. **Right-size**: Don't over-provision, use the minimal config that fits your needs
4. **Zonal clusters**: Cheaper than regional (already configured)
5. **Standard network tier**: Cheaper egress (already configured)

## Deployment

```bash
# 1. Choose configuration
cp terraform.tfvars.balanced terraform.tfvars

# 2. Edit project ID
vim terraform.tfvars

# 3. Deploy
terraform init
terraform apply

# 4. Get cluster credentials
$(terraform output -raw kubeconfig_command)

# 5. Deploy applications
cd ../..
./scripts/deploy-gke.sh infrastructure
./scripts/deploy-gke.sh analytics
```

## Monitoring Resources

After deployment, monitor resource usage:

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -A

# Describe node to see allocatable resources
kubectl describe node
```
