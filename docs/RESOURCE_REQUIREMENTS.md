# Resource Requirements Calculation

## Infrastructure Components

### cert-manager (3 pods)
- **Controller**: 50m CPU, 64Mi RAM (request) / 100m CPU, 128Mi RAM (limit)
- **Webhook**: 25m CPU, 32Mi RAM (request) / 50m CPU, 64Mi RAM (limit)
- **CA Injector**: 25m CPU, 64Mi RAM (request) / 50m CPU, 128Mi RAM (limit)
- **Total**: 100m CPU, 160Mi RAM (requests) / 200m CPU, 320Mi RAM (limits)

### ingress-nginx (1 pod)
- **Controller**: 100m CPU, 128Mi RAM (request) / 200m CPU, 256Mi RAM (limit)
- **Total**: 100m CPU, 128Mi RAM (requests) / 200m CPU, 256Mi RAM (limits)

### Infrastructure Subtotal
- **Requests**: 200m CPU, 288Mi RAM (~0.3 GB)
- **Limits**: 400m CPU, 576Mi RAM (~0.6 GB)

## Analytics Components (Minimal Setup)

### Artemis MQTT
- **Typical**: 250m CPU, 512Mi RAM (request) / 500m CPU, 1Gi RAM (limit)

### ClickHouse (1 replica)
- **Typical**: 500m CPU, 1Gi RAM (request) / 1000m CPU, 2Gi RAM (limit)

### Apache NiFi (1 node)
- **Typical**: 500m CPU, 1Gi RAM (request) / 1000m CPU, 2Gi RAM (limit)

### Zookeeper (for NiFi)
- **Typical**: 100m CPU, 256Mi RAM (request) / 200m CPU, 512Mi RAM (limit)

### Redis
- **Typical**: 100m CPU, 128Mi RAM (request) / 200m CPU, 256Mi RAM (limit)

### Dagster
- **Daemon**: 250m CPU, 512Mi RAM (request) / 500m CPU, 1Gi RAM (limit)
- **Webserver**: 100m CPU, 256Mi RAM (request) / 200m CPU, 512Mi RAM (limit)
- **Total**: 350m CPU, 768Mi RAM (requests) / 700m CPU, 1.5Gi RAM (limits)

### Prometheus
- **Server**: 500m CPU, 512Mi RAM (request) / 1000m CPU, 1Gi RAM (limit)

### Grafana
- **Server**: 100m CPU, 128Mi RAM (request) / 200m CPU, 256Mi RAM (limit)

### Dashboard API
- **Server**: 100m CPU, 128Mi RAM (request) / 200m CPU, 256Mi RAM (limit)

### Analytics Subtotal (All Components)
- **Requests**: ~2.5 CPU, ~4.5 GB RAM
- **Limits**: ~5 CPU, ~9 GB RAM

## Total Resource Requirements

### Minimal Setup (Infrastructure + Artemis + ClickHouse + Redis)
- **Requests**: ~1 CPU, ~2 GB RAM
- **Limits**: ~2 CPU, ~4 GB RAM
- **Recommended Node**: e2-standard-2 (2 vCPU, 8 GB RAM)

### Medium Setup (Infrastructure + Artemis + ClickHouse + NiFi + Redis + Dagster)
- **Requests**: ~2 CPU, ~4 GB RAM
- **Limits**: ~4 CPU, ~8 GB RAM
- **Recommended Node**: e2-standard-4 (4 vCPU, 16 GB RAM)

### Full Setup (All Components)
- **Requests**: ~3 CPU, ~5 GB RAM
- **Limits**: ~6 CPU, ~10 GB RAM
- **Recommended Nodes**: 2x e2-standard-4 OR 1x e2-standard-8

## GKE System Overhead

GKE reserves resources for system components:
- **kube-system pods**: ~200m CPU, ~500Mi RAM
- **GKE add-ons**: ~100m CPU, ~200Mi RAM
- **Total overhead**: ~300m CPU, ~700Mi RAM

## Node Sizing Recommendations

### Option 1: Cost-Optimized (Minimal)
```hcl
machine_type   = "e2-standard-2"  # 2 vCPU, 8 GB RAM
min_node_count = 1
max_node_count = 2
use_spot_vms   = true
```
**Supports**: Infrastructure + Artemis + ClickHouse + Redis
**Cost**: ~$25-50/month with Spot VMs

### Option 2: Balanced (Recommended)
```hcl
machine_type   = "e2-standard-4"  # 4 vCPU, 16 GB RAM
min_node_count = 1
max_node_count = 3
use_spot_vms   = true
```
**Supports**: All components except heavy NiFi workloads
**Cost**: ~$50-150/month with Spot VMs

### Option 3: Production
```hcl
machine_type   = "e2-standard-4"  # 4 vCPU, 16 GB RAM
min_node_count = 2
max_node_count = 5
use_spot_vms   = false
```
**Supports**: All components with HA
**Cost**: ~$200-500/month

## Current Default (e2-medium)

**Current setup**: e2-medium (2 vCPU, 4 GB RAM)
- **Available after overhead**: ~1.7 vCPU, ~3.3 GB RAM
- **Can support**: Infrastructure + 1-2 lightweight analytics components
- **⚠️ WARNING**: Not enough for full analytics stack!

## Recommendations

1. **For testing infrastructure only**: e2-medium is OK
2. **For Artemis + basic analytics**: Use e2-standard-2
3. **For full analytics stack**: Use e2-standard-4
4. **For production**: Use e2-standard-4 with min 2 nodes
