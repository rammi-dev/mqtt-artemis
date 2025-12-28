# GKE Cluster Terraform

This Terraform configuration creates a **single GKE cluster** for hosting both infrastructure and analytics workloads.

## What This Creates

✅ **GCP Resources Only:**
- GKE cluster (zonal, cost-optimized)
- Node pool with autoscaling (Spot VMs)
- Static external IP address for ingress
- Network configuration

❌ **NOT Included (Deploy via Helm):**
- cert-manager → Deploy to `cert-manager` namespace via Helm
- ingress-nginx → Deploy to `ingress-nginx` namespace via Helm
- edge-analytics → Deploy to `edge` namespace via Helm

## Architecture

```
GKE Cluster (edge-analytics)
├── Namespace: cert-manager
│   └── cert-manager (Helm)
├── Namespace: ingress-nginx
│   └── ingress-nginx (Helm)
└── Namespace: edge
    └── edge-analytics (Helm)
        ├── Artemis MQTT
        ├── NiFi
        ├── ClickHouse
        ├── Dagster
        ├── Grafana
        └── Dashboard API
```

## Usage

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Set your project_id, region, zone
```

### 2. Initialize and Apply Terraform

```bash
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl

```bash
$(terraform output -raw kubeconfig_command)
```

### 4. Deploy Infrastructure via Helm

```bash
# Get the static IP
INGRESS_IP=$(terraform output -raw ingress_ip)

# Deploy cert-manager
helm upgrade --install cert-manager charts/infrastructure/cert-manager/ \
  --namespace cert-manager \
  --create-namespace \
  --wait

# Deploy ingress-nginx
helm upgrade --install ingress-nginx charts/infrastructure/ingress-nginx/ \
  --namespace ingress-nginx \
  --create-namespace \
  --set ingress-nginx.controller.service.loadBalancerIP=$INGRESS_IP \
  --wait
```

### 5. Deploy Analytics via Helm

```bash
# Deploy edge-analytics
helm upgrade --install edge-analytics charts/edge-analytics/ \
  --namespace edge \
  --create-namespace \
  --set ingress.domain=${INGRESS_IP}.nip.io \
  --wait
```

## Outputs

- `cluster_name` - Name of the GKE cluster
- `cluster_endpoint` - Cluster API endpoint (sensitive)
- `cluster_ca_certificate` - Cluster CA certificate (sensitive)
- `ingress_ip` - Static IP for ingress controller
- `nip_io_domain` - Wildcard domain (e.g., `34.118.224.103.nip.io`)
- `kubeconfig_command` - Command to configure kubectl

## Cost Optimization

This configuration is optimized for cost:

| Feature | Savings |
|---------|---------|
| Zonal cluster (vs Regional) | ~66% on control plane |
| Spot VMs (vs Standard) | 60-91% on compute |
| e2-medium (vs n2-standard) | ~50% on compute |
| pd-standard (vs pd-ssd) | ~80% on storage |
| STANDARD network tier | ~25% on egress |

**Estimated Monthly Cost**: ~$12-40/month (1-3 nodes)

## Namespace Strategy

- **cert-manager**: Infrastructure - TLS certificate management
- **ingress-nginx**: Infrastructure - Ingress controller
- **edge**: Analytics - All edge analytics workloads

This separation allows:
- Independent lifecycle management
- Clear resource organization
- Easy RBAC configuration
- Simplified monitoring and logging

## Cleanup

```bash
# Delete Helm releases first
helm uninstall edge-analytics -n edge
helm uninstall ingress-nginx -n ingress-nginx
helm uninstall cert-manager -n cert-manager

# Then destroy Terraform resources
terraform destroy
```
