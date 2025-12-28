# Edge Analytics Platform on GKE

A complete edge analytics platform running on Google Kubernetes Engine (GKE) with clean separation between infrastructure and application layers.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Components](#components)
- [Deployment Process](#deployment-process)
- [Cost Optimization](#cost-optimization)
- [Documentation](#documentation)

## 🏗️ Architecture Overview

![Architecture Diagram](docs/infrastructure_architecture_1766932275192.png)

### Design Principles

1. **Clean Separation of Concerns**
   - **Terraform** → GCP cloud resources only (GKE cluster, networking, IPs)
   - **Helm** → Kubernetes resources only (applications, operators, services)

2. **Single Cluster Architecture**
   - One cost-optimized GKE cluster
   - Namespace-based isolation for infrastructure and analytics workloads

3. **Infrastructure vs Analytics**
   - **Infrastructure** (cert-manager, ingress-nginx) → Core K8s components
   - **Analytics** (NiFi, ClickHouse, Grafana, etc.) → Application workloads

### Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│ Terraform (GCP Resources)                               │
│ ├── GKE Cluster (zonal, europe-central2-b)            │
│ ├── Node Pool (1-3 nodes, Spot VMs)                   │
│ └── Static IP (for ingress)                           │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (3 Namespaces)                      │
│                                                         │
│ ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│ │cert-manager │  │ingress-nginx │  │     edge       │ │
│ │             │  │              │  │                │ │
│ │ • cert-mgr  │  │ • NGINX      │  │ • Artemis MQTT│ │
│ │ • ClusterIs │  │ • LoadBal    │  │ • Apache NiFi │ │
│ │             │  │              │  │ • ClickHouse  │ │
│ │             │  │              │  │ • Dagster     │ │
│ │             │  │              │  │ • Grafana     │ │
│ │             │  │              │  │ • Dashboard   │ │
│ └─────────────┘  └──────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────┘
                          ↑
┌─────────────────────────────────────────────────────────┐
│ Helm Charts                                             │
│ ├── infrastructure/cert-manager                        │
│ ├── infrastructure/ingress-nginx                       │
│ └── edge-analytics                                     │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- GCP account with billing enabled
- `gcloud` CLI installed and authenticated
- `terraform` >= 1.5.0
- `kubectl` >= 1.21
- `helm` >= 3.x

### One-Command Deployment

```bash
# 1. Configure Terraform
cd terraform/gke
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Set your project_id

# 2. Deploy everything
cd ../..
./scripts/deploy-gke.sh
```

This script automatically:
1. ✅ Creates GKE cluster via Terraform
2. ✅ Configures kubectl
3. ✅ Deploys infrastructure (cert-manager, ingress-nginx)
4. ✅ Deploys analytics workloads (edge-analytics)

### Access Services

After deployment, get service URLs:

```bash
./scripts/access-info.sh
```

Services are accessible via nip.io:
- **Grafana**: `https://grafana.<INGRESS_IP>.nip.io`
- **NiFi**: `https://nifi.<INGRESS_IP>.nip.io`
- **Dagster**: `https://dagster.<INGRESS_IP>.nip.io`
- **Dashboard API**: `https://api.<INGRESS_IP>.nip.io`

## 📁 Repository Structure

```
artemis/
├── terraform/
│   └── gke/                      # Terraform for GKE cluster (GCP only)
│       ├── main.tf               # GKE cluster, node pool, static IP
│       ├── variables.tf
│       ├── terraform.tfvars.example
│       └── README.md
│
├── charts/
│   ├── infrastructure/           # Infrastructure Helm charts
│   │   ├── cert-manager/        # TLS certificate management
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/       # ClusterIssuers
│   │   │
│   │   └── ingress-nginx/       # NGINX Ingress Controller
│   │       ├── Chart.yaml
│   │       └── values.yaml
│   │
│   ├── edge-analytics/          # Analytics umbrella chart
│   │   ├── Chart.yaml           # Dependencies: operators, apps
│   │   ├── values.yaml
│   │   └── crds/                # Custom resources
│   │
│   └── producer/                # Test data producer
│
├── apps/
│   └── flutter-dashboard/       # Flutter dashboard app
│
├── scripts/
│   ├── deploy-gke.sh           # Automated deployment
│   ├── deploy.sh               # Legacy deployment
│   └── access-info.sh          # Service access info
│
├── docs/
│   ├── ARCHITECTURE.md         # Detailed architecture
│   └── infrastructure_architecture_*.png
│
├── ARCHITECTURE.md             # Architecture overview
├── INFRASTRUCTURE.md           # Infrastructure quick reference
└── README.md                   # This file
```

## 🧩 Components

### Terraform Layer (`terraform/gke/`)

**Purpose:** Provision GCP cloud resources

**Creates:**
- GKE cluster (zonal, cost-optimized)
- Node pool with autoscaling (Spot VMs)
- Static external IP for ingress

**Does NOT create:**
- Kubernetes resources (moved to Helm)
- cert-manager, ingress-nginx (moved to Helm)

### Infrastructure Layer (`charts/infrastructure/`)

**Purpose:** Core Kubernetes infrastructure components

#### cert-manager
- Automatic TLS certificate management
- ClusterIssuers:
  - `letsencrypt-prod` - Production Let's Encrypt
  - `letsencrypt-staging` - Testing certificates
  - `selfsigned-issuer` - For nip.io domains

#### ingress-nginx
- NGINX Ingress Controller
- Routes external traffic to services
- Uses static IP from Terraform

### Analytics Layer (`charts/edge-analytics/`)

**Purpose:** Edge analytics application workloads

**Components:**
- **Artemis MQTT** - Message broker (port 1883)
- **Apache NiFi** - Data ingestion and processing
- **ClickHouse** - Time-series database
- **Dagster** - Data orchestration
- **Grafana** - Monitoring dashboards
- **Dashboard API** - REST API for dashboards
- **Test Producer** - Generates test telemetry data

**Data Flow:**
```
IoT Devices → MQTT → NiFi → ClickHouse
                       ↓
                     Redis (cache)
                       ↓
                  Dashboard API → Flutter App
```

## 🔄 Deployment Process

### Automated Deployment (Recommended)

```bash
./scripts/deploy-gke.sh
```

**Steps performed:**
1. Terraform applies GKE cluster configuration
2. Retrieves cluster credentials and static IP
3. Configures kubectl
4. Deploys cert-manager to `cert-manager` namespace
5. Deploys ingress-nginx to `ingress-nginx` namespace
6. Deploys edge-analytics to `edge` namespace

### Manual Deployment

#### Step 1: Create GKE Cluster

```bash
cd terraform/gke
terraform init
terraform apply
```

#### Step 2: Configure kubectl

```bash
$(terraform output -raw kubeconfig_command)
```

#### Step 3: Deploy Infrastructure

```bash
cd ../..
INGRESS_IP=$(cd terraform/gke && terraform output -raw ingress_ip)

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

#### Step 4: Deploy Analytics

```bash
# Update dependencies
cd charts/edge-analytics
helm dependency update
cd ../..

# Deploy
helm upgrade --install edge-analytics charts/edge-analytics/ \
  --namespace edge \
  --create-namespace \
  --wait
```

## 💰 Cost Optimization

The infrastructure is optimized for cost efficiency:

| Feature | Configuration | Savings |
|---------|--------------|---------|
| **Cluster Type** | Zonal (vs Regional) | ~66% on control plane |
| **Compute** | Spot VMs | 60-91% vs standard VMs |
| **Machine Type** | e2-medium | ~50% vs n2-standard |
| **Disk** | pd-standard | ~80% vs pd-ssd |
| **Network** | STANDARD tier | ~25% on egress |
| **Scaling** | Min 1 node | Minimal baseline cost |

**Estimated Monthly Cost:** $12-40 (1-3 nodes)

### Cost Breakdown
- GKE control plane: Free (zonal cluster)
- Compute (1x e2-medium Spot VM): ~$7-10/month
- Disk (50GB pd-standard): ~$2/month
- Static IP: ~$3/month
- Network egress: Variable

## 📚 Documentation

### Main Documentation
- **[README.md](README.md)** - This file (repository overview)
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture documentation
- **[INFRASTRUCTURE.md](INFRASTRUCTURE.md)** - Infrastructure quick reference

### Component Documentation
- **[terraform/gke/README.md](terraform/gke/README.md)** - Terraform usage
- **[charts/infrastructure/cert-manager/README.md](charts/infrastructure/cert-manager/README.md)** - cert-manager details
- **[charts/infrastructure/ingress-nginx/README.md](charts/infrastructure/ingress-nginx/README.md)** - ingress-nginx details
- **[charts/edge-analytics/README.md](charts/edge-analytics/README.md)** - Analytics platform details

### Additional Resources
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Original architecture documentation
- **[apps/flutter-dashboard/README.md](apps/flutter-dashboard/README.md)** - Flutter app documentation

## 🔧 Common Operations

### Check Deployment Status

```bash
# All pods
kubectl get pods -A

# Infrastructure
kubectl get pods -n cert-manager
kubectl get pods -n ingress-nginx

# Analytics
kubectl get pods -n edge

# Ingress resources
kubectl get ingress -A
```

### View Logs

```bash
# cert-manager
kubectl logs -n cert-manager -l app=cert-manager

# ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# NiFi
kubectl logs -n edge -l app=nifi
```

### Scale Resources

```bash
# Scale node pool
cd terraform/gke
# Edit terraform.tfvars: max_node_count = 5
terraform apply

# Scale application replicas
kubectl scale deployment <name> -n edge --replicas=3
```

### Upgrade Components

```bash
# Upgrade infrastructure
helm upgrade cert-manager charts/infrastructure/cert-manager/ -n cert-manager
helm upgrade ingress-nginx charts/infrastructure/ingress-nginx/ -n ingress-nginx

# Upgrade analytics
helm upgrade edge-analytics charts/edge-analytics/ -n edge
```

### Cleanup

```bash
# Delete Helm releases
helm uninstall edge-analytics -n edge
helm uninstall ingress-nginx -n ingress-nginx
helm uninstall cert-manager -n cert-manager

# Destroy GKE cluster
cd terraform/gke
terraform destroy
```

## 🛠️ Troubleshooting

### Terraform Issues

```bash
cd terraform/gke
terraform init -upgrade
terraform validate
terraform plan
```

### Certificate Issues

```bash
# Check ClusterIssuers
kubectl get clusterissuers

# Check certificates
kubectl get certificates -A

# Describe certificate
kubectl describe certificate <name> -n <namespace>
```

### Ingress Issues

```bash
# Check ingress controller
kubectl get svc -n ingress-nginx

# Check ingress resources
kubectl describe ingress <name> -n <namespace>

# Test connectivity
curl -k https://<service>.<INGRESS_IP>.nip.io
```

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test deployment
4. Submit pull request

## 📄 License

[Add your license here]

## 🙋 Support

For issues and questions:
- Check documentation in `docs/`
- Review component READMEs
- Check Helm chart values and templates

---

**Ready to deploy?**

```bash
./scripts/deploy-gke.sh
```
