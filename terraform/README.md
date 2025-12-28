# Infrastructure Structure - Final

## Directory Structure

```
terraform/
└── gke/                          # Single GKE cluster configuration
    ├── main.tf                   # GCP resources only
    ├── variables.tf              # Configuration variables
    ├── terraform.tfvars.example  # Example configuration
    └── README.md                 # Documentation

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

## What Each Directory Does

### `terraform/gke/` - GCP Resources
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
1. Terraform (terraform/gke/)
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
