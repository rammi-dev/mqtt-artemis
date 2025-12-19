# GKE Terraform Module - Edge Analytics

This Terraform module creates a **cost-optimized GKE zonal cluster** with:
- ✅ Spot VMs (up to 91% cheaper)
- ✅ cert-manager + Let's Encrypt
- ✅ NGINX Ingress with nip.io support
- ✅ Pre-configured ingress for all services

## Cost Optimization Features

| Feature | Savings |
|---------|---------|
| Zonal cluster (vs Regional) | ~66% on control plane |
| Spot VMs (vs Standard) | 60-91% on compute |
| e2-medium (vs n2-standard) | ~50% on compute |
| pd-standard (vs pd-ssd) | ~80% on storage |
| Standard network tier | ~25% on egress |

### Estimated Monthly Cost

| Configuration | Cost |
|---------------|------|
| 1 node (minimum) | ~$12-15/month |
| 3 nodes (recommended) | ~$30-40/month |

## Prerequisites

1. **GCP Project** with billing enabled
2. **gcloud CLI** authenticated
3. **Terraform** >= 1.5.0
4. **kubectl** installed

## Quick Start

```bash
# 1. Navigate to terraform directory
cd terraform/gke

# 2. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Set your email and project ID

# 3. Initialize Terraform
terraform init

# 4. Review the plan
terraform plan

# 5. Apply (creates cluster)
terraform apply

# 6. Configure kubectl
$(terraform output -raw kubeconfig_command)

# 7. Verify cluster
kubectl get nodes
```

## What Gets Created

### Infrastructure
- GKE zonal cluster in `us-central1-a`
- Node pool with Spot VMs (e2-medium)
- Static IP for ingress

### Kubernetes Resources
- **cert-manager** namespace + Helm release
- **ingress-nginx** namespace + Helm release
- **edge** namespace for applications
- ClusterIssuers:
  - `letsencrypt-prod` - Production certificates
  - `letsencrypt-staging` - Testing (no rate limits)
  - `selfsigned-issuer` - Internal services

### Ingress Resources (nip.io)
Pre-configured ingress for:
- `grafana.<IP>.nip.io`
- `nifi.<IP>.nip.io`
- `dagster.<IP>.nip.io`
- `api.<IP>.nip.io`

## Usage

### Get Service URLs

```bash
terraform output service_urls
```

Output:
```
{
  "grafana"       = "https://grafana.34.XX.XX.XX.nip.io"
  "nifi"          = "https://nifi.34.XX.XX.XX.nip.io"
  "dagster"       = "https://dagster.34.XX.XX.XX.nip.io"
  "dashboard_api" = "https://api.34.XX.XX.XX.nip.io"
}
```

### Deploy Edge Analytics

After cluster creation:

```bash
# Configure kubectl
$(terraform output -raw kubeconfig_command)

# Deploy edge analytics
cd ../../
./scripts/deploy.sh all
```

### Access Services

```bash
# Get the nip.io domain
terraform output nip_io_domain

# Access Grafana
open "https://grafana.$(terraform output -raw ingress_ip).nip.io"

# Access NiFi
open "https://nifi.$(terraform output -raw ingress_ip).nip.io"
```

## nip.io Explained

[nip.io](https://nip.io) provides wildcard DNS without configuration:

| Request | Resolves To |
|---------|-------------|
| `app.10.0.0.1.nip.io` | `10.0.0.1` |
| `grafana.34.56.78.90.nip.io` | `34.56.78.90` |
| `*.192.168.1.100.nip.io` | `192.168.1.100` |

**Benefits:**
- No DNS configuration needed
- Works immediately with any IP
- Perfect for dev/staging environments

**Limitations:**
- Can't use Let's Encrypt HTTP-01 challenge (rate limits on nip.io)
- Self-signed certificates for HTTPS (browser warning)
- For production, use a real domain with DNS-01 challenge

## Let's Encrypt with Real Domain

For production with valid certificates:

1. **Get a domain** (e.g., `edge.example.com`)

2. **Configure DNS**:
   ```
   *.edge.example.com  A  <ingress_ip>
   ```

3. **Update ingress** to use real domain:
   ```yaml
   annotations:
     cert-manager.io/cluster-issuer: letsencrypt-prod
   spec:
     tls:
       - hosts:
           - grafana.edge.example.com
         secretName: grafana-tls
     rules:
       - host: grafana.edge.example.com
   ```

## Customization

### Change Machine Type

```hcl
# In terraform.tfvars
machine_type = "e2-standard-4"  # More resources
```

### Disable Spot VMs

```hcl
# In terraform.tfvars
use_spot_vms = false  # For production stability
```

### Scale Nodes

```hcl
# In terraform.tfvars
min_node_count = 2
max_node_count = 5
```

### Change Region

```hcl
# In terraform.tfvars (check pricing first!)
region = "europe-west1"
zone   = "europe-west1-b"
```

## Troubleshooting

### Nodes not starting

```bash
# Check node pool status
gcloud container node-pools describe edge-analytics-node-pool \
  --cluster edge-analytics \
  --zone us-central1-a \
  --project data-cluster-gke1

# Check for quota issues
gcloud compute regions describe us-central1 --project data-cluster-gke1
```

### cert-manager issues

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check certificate status
kubectl get certificates -A
kubectl describe certificate wildcard-tls -n edge

# Check ClusterIssuers
kubectl get clusterissuers
```

### Ingress not working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Check ingress resources
kubectl get ingress -A

# Verify static IP is assigned
kubectl get svc -n ingress-nginx
```

### Spot VM preemption

```bash
# Check node events
kubectl get events --field-selector reason=PreemptionBySpotVM

# For critical workloads, add pod anti-affinity or use standard VMs
```

## Cleanup

```bash
# Destroy all resources
terraform destroy

# Or just remove cluster (keep state)
terraform destroy -target=google_container_cluster.primary
```

## Cost Monitoring

```bash
# Enable billing export (recommended)
gcloud billing budgets create \
  --billing-account=BILLING_ACCOUNT_ID \
  --display-name="GKE Budget" \
  --budget-amount=50USD \
  --threshold-rule=percent=80
```

## Security Notes

1. **Spot VMs** can be preempted - don't use for stateful workloads without proper backup
2. **Self-signed certs** show browser warnings - acceptable for dev/staging
3. **Public cluster** - consider `enable_private_nodes = true` for production
4. **Workload Identity** is enabled - use it instead of service account keys

## References

- [GKE Pricing](https://cloud.google.com/kubernetes-engine/pricing)
- [Spot VMs](https://cloud.google.com/kubernetes-engine/docs/concepts/spot-vms)
- [cert-manager](https://cert-manager.io/docs/)
- [nip.io](https://nip.io/)
- [NGINX Ingress](https://kubernetes.github.io/ingress-nginx/)
