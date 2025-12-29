# GKE Infrastructure - Quick Reference

## Architecture Diagram

![GKE Infrastructure Architecture](docs/infrastructure_architecture_1766932275192.png)

## ✅ Clean Structure (No Duplication)

```
terraform/
└── gke/                    ← ONLY THIS for GKE cluster
    ├── main.tf            (GCP resources only)
    ├── variables.tf
    ├── terraform.tfvars.example
    └── README.md

charts/infrastructure/      ← Infrastructure components (Helm)
├── cert-manager/
└── ingress-nginx/

charts/edge-analytics/      ← Analytics workloads (Helm)

scripts/
└── deploy-gke.sh          ← One-command deployment
```

## Removed (Not Needed)

- ❌ `terraform/modules/gke-cluster/` - Removed (was for multi-environment)
- ❌ `terraform/environments/production/` - Removed (single cluster approach)
- ❌ `terraform/environments/analytics/` - Removed (single cluster approach)

## What You Have Now

### 1. Single Terraform Configuration
**Location:** `gke-infrastructure/`

**Creates:**
- 1 GKE cluster (zonal, europe-central2-b)
- Node pool with autoscaling (1-3 nodes, Spot VMs)
- Static IP for ingress

**Usage:**
```bash
cd gke-infrastructure
terraform init
terraform apply
```

### 2. Infrastructure Helm Charts
**Location:** `charts/infrastructure/`

**Deploys:**
- `cert-manager` → namespace: cert-manager
- `ingress-nginx` → namespace: ingress-nginx
- `postgres-operator` → namespace: postgres-operator
- `keycloak-db` → namespace: keycloak (PostgreSQL cluster)
- `keycloak` → namespace: keycloak (IAM)

**Usage:**
```bash
# Deployed automatically by deploy-gke.sh
# Or manually:
helm install cert-manager charts/infrastructure/cert-manager/ -n cert-manager --create-namespace
helm install ingress-nginx charts/infrastructure/ingress-nginx/ -n ingress-nginx --create-namespace
helm install postgres-operator charts/infrastructure/postgres-operator/ -n postgres-operator --create-namespace
helm install keycloak-db charts/infrastructure/keycloak-db/ -n keycloak --create-namespace
helm install keycloak charts/infrastructure/keycloak/ -n keycloak --create-namespace
```

### 3. Analytics Helm Chart
**Location:** `charts/edge-analytics/`

**Deploys:**
- All analytics workloads → namespace: edge

**Usage:**
```bash
# Deployed automatically by deploy-gke.sh
# Or manually:
helm install edge-analytics charts/edge-analytics/ -n edge --create-namespace
```

## Deployment

### Option 1: Automated (Recommended)
```bash
./scripts/deploy-gke.sh
```

This does everything:
1. ✅ Terraform apply (GKE cluster)
2. ✅ Configure kubectl
3. ✅ Deploy cert-manager
4. ✅ Deploy ingress-nginx
5. ✅ Deploy postgres-operator (for Keycloak)
6. ✅ Deploy keycloak-db (PostgreSQL)
7. ✅ Deploy keycloak (IAM)
8. ✅ Deploy edge-analytics

### Option 2: Manual Steps
```bash
# 1. Create GKE cluster
cd gke-infrastructure
terraform apply
INGRESS_IP=$(terraform output -raw ingress_ip)
$(terraform output -raw kubeconfig_command)

# 2. Deploy infrastructure
cd ../..
helm install cert-manager charts/infrastructure/cert-manager/ -n cert-manager --create-namespace
helm install ingress-nginx charts/infrastructure/ingress-nginx/ -n ingress-nginx --create-namespace \
  --set ingress-nginx.controller.service.loadBalancerIP=$INGRESS_IP

# 3. Deploy analytics
helm install edge-analytics charts/edge-analytics/ -n edge --create-namespace
```

## Architecture

```
GKE Cluster (edge-analytics)
│
├── Namespace: cert-manager
│   └── cert-manager (Helm)
│       ├── Controller
│       ├── Webhook
│       └── ClusterIssuers (letsencrypt-prod, letsencrypt-staging, selfsigned)
│
├── Namespace: ingress-nginx
│   └── ingress-nginx (Helm)
│       ├── Controller
│       └── LoadBalancer Service (static IP)
│
├── Namespace: postgres-operator
│   └── postgres-operator (Helm)
│       └── Postgres Operator (manages PostgreSQL clusters)
│
├── Namespace: keycloak
│   ├── keycloak-db (PostgreSQL cluster via Postgres Operator)
│   └── keycloak (Helm)
│       ├── Keycloak Operator
│       ├── Keycloak Instance (managed by operator)
│       ├── Ingress (managed by Helm)
│       └── Certificate (managed by cert-manager)
│
└── Namespace: edge
    └── edge-analytics (Helm)
        ├── Artemis MQTT
        ├── Apache NiFi
        ├── ClickHouse
        ├── Dagster
        ├── Grafana
        └── Dashboard API
```

## Key Points

✅ **Single Cluster:** One GKE cluster for everything
✅ **Terraform for GCP:** Only cloud resources (GKE, IP, network)
✅ **Helm for K8s:** All Kubernetes resources (cert-manager, ingress, apps)
✅ **Namespace Separation:** Infrastructure vs Analytics
✅ **Cost Optimized:** Spot VMs, zonal cluster, minimal resources

## Next Steps

1. **Configure:**
   ```bash
   cd gke-infrastructure
   cp terraform.tfvars.example terraform.tfvars
   vim terraform.tfvars  # Set your project_id
   ```

2. **Deploy:**
   ```bash
   cd ../..
   ./scripts/deploy-gke.sh
   ```

3. **Verify:**
   ```bash
   kubectl get pods -A
   kubectl get ingress -A
   ```

4. **Access:**
   ```bash
   ./scripts/access-info.sh
   ```
