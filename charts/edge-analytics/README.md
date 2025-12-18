# Edge Analytics - Umbrella Chart

This is an **umbrella chart** that uses only Helm dependencies. No templates to maintain!

## Structure

```
edge-analytics/
├── Chart.yaml       # Dependencies only
├── values.yaml      # Configuration for all dependencies
└── crds/            # Only your custom CRDs
    ├── nifi-cluster.yaml
    └── clickhouse-cluster.yaml
```

## Dependencies (Auto-Downloaded)

All infrastructure is managed via Helm dependencies:

1. **activemq-artemis** - MQTT broker (local chart)
2. **clickhouse-operator** - ClickHouse operator from Altinity
3. **zookeeper** - From Bitnami charts
4. **nifikop** - NiFi operator

## Installation

```bash
# 1. Update dependencies (downloads all charts)
helm dependency update charts/edge-analytics/

# 2. Install everything
helm install edge-analytics charts/edge-analytics/ \
  --namespace edge \
  --create-namespace

# 3. Apply CRDs (after operators are ready)
kubectl apply -f charts/edge-analytics/crds/
```

## Benefits

✅ **No template maintenance** - All managed by upstream charts  
✅ **Easy upgrades** - Just bump dependency versions  
✅ **Version control** - Only your CRDs in git  
✅ **Consistent** - Use official, tested charts

## What You Maintain

Only **2 files** with your custom configuration:
- `crds/nifi-cluster.yaml` - Your NiFi cluster spec
- `crds/clickhouse-cluster.yaml` - Your ClickHouse cluster spec

Everything else is managed by dependencies!
