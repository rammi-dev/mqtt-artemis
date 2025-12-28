# GKE Infrastructure - Terraform Configuration

Terraform configuration for provisioning Google Kubernetes Engine (GKE) clusters.

## Structure

```
gke-infrastructure/
├── gke/                    # Main GKE cluster configuration
│   ├── main.tf            (GCP resources only)
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── terraform.tfvars.minimal      # e2-standard-2 setup
│   ├── terraform.tfvars.balanced     # e2-standard-4 (recommended)
│   ├── terraform.tfvars.production   # HA production setup
│   ├── CONFIGURATIONS.md  # Configuration guide
│   └── README.md
└── README.md              # This file
```

charts/
├── infrastructure/               # Infrastructure Helm charts
│   ├── cert-manager/            # TLS certificate management
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── templates/
│   │   │   ├── clusterissuer-letsencrypt-prod.yaml
│   │   │   ├── clusterissuer-letsencrypt-staging.yaml
│   │   │   └── clusterissuer-selfsigned.yaml
│   │   └── README.md
│   │
│   └── ingress-nginx/           # NGINX Ingress Controller
│       ├── Chart.yaml
│       ├── values.yaml
│       └── README.md
│
└── edge-analytics/              # Analytics workloads
    └── ...

scripts/
└── deploy-gke.sh                # Automated deployment
```

## Quick Start

### 1. Choose Configuration

```bash
cd gke-infrastructure/gke

# Choose based on your needs:
cp terraform.tfvars.balanced terraform.tfvars  # RECOMMENDED (full stack)
# OR
cp terraform.tfvars.minimal terraform.tfvars   # Minimal (Artemis + ClickHouse)
# OR
cp terraform.tfvars.production terraform.tfvars # Production HA
```

### 2. Configure

Edit `terraform.tfvars` with your GCP project ID:

```hcl
project_id = "your-gcp-project-id"
```

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply
terraform apply
```

### 4. Get Cluster Credentials

```bash
# Configure kubectl
$(terraform output -raw kubeconfig_command)

# Verify
kubectl get nodes
```

## Configuration Options

See [gke/CONFIGURATIONS.md](gke/CONFIGURATIONS.md) for detailed configuration options and resource requirements.

## What Each Directory Does

### `gke-infrastructure/` - GCP Resources
**Purpose:** Create GKE cluster and cloud infrastructure

**Contains:**
- GKE cluster (zonal, cost-optimized)
- Node pool with autoscaling (Spot VMs)
- Static external IP for ingress
- Network configuration

**Deploy:** `terraform apply`

### `charts/infrastructure/` - Kubernetes Infrastructure
**Purpose:** Deploy infrastructure components to the cluster

**Contains:**
- `cert-manager/` - TLS certificate management (namespace: cert-manager)
- `ingress-nginx/` - Ingress controller (namespace: ingress-nginx)

**Deploy:** Via `deploy-gke.sh` or manually with `helm install`

### `charts/edge-analytics/` - Analytics Workloads
**Purpose:** Deploy analytics applications

**Contains:**
- Artemis MQTT
- Apache NiFi
- ClickHouse
- Dagster
- Grafana
- Dashboard API

**Deploy:** Via `deploy-gke.sh` or manually with `helm install` (namespace: edge)

## Deployment Flow

```
1. Terraform (gke-infrastructure/)
   ↓ Creates GKE cluster + static IP
   
2. kubectl configuration
   ↓ Connects to cluster
   
3. Infrastructure Helm charts (charts/infrastructure/)
   ↓ Deploys cert-manager, ingress-nginx
   
4. Analytics Helm chart (charts/edge-analytics/)
   ↓ Deploys all analytics workloads
```

## Quick Start

```bash
# One command deployment
./scripts/deploy-gke.sh
```

This script handles all 4 steps automatically.

## Namespace Strategy

| Namespace | Purpose | Deployed By |
|-----------|---------|-------------|
| `cert-manager` | TLS certificate management | Helm (infrastructure) |
| `ingress-nginx` | Ingress controller | Helm (infrastructure) |
| `edge` | Analytics workloads | Helm (edge-analytics) |

## Why This Structure?

✅ **Clean Separation:**
- Terraform = GCP cloud resources
- Helm = Kubernetes resources

✅ **Single Cluster:**
- Cost-efficient
- Easy to manage
- Namespace isolation

✅ **Reusable Charts:**
- Infrastructure charts can be used in other projects
- Version controlled
- Easy to upgrade

✅ **Automated Deployment:**
- One script deploys everything
- Consistent and repeatable
- Error handling included
