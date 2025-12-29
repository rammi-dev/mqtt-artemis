# Postgres Operator

Zalando Postgres Operator for managing PostgreSQL clusters on Kubernetes.

## Installation

```bash
./scripts/deploy-gke.sh postgres-operator
```

## Features

- Automated PostgreSQL cluster provisioning
- High availability with streaming replication
- Automated backups and point-in-time recovery
- Connection pooling with PgBouncer
- Monitoring integration

## Creating a Database

After installing the operator, create PostgreSQL clusters using the `postgresql` CRD:

```yaml
apiVersion: acid.zalan.do/v1
kind: postgresql
metadata:
  name: my-database
spec:
  teamId: "myteam"
  volume:
    size: 10Gi
  numberOfInstances: 2
  users:
    myuser:
      - superuser
  databases:
    mydb: myuser
  postgresql:
    version: "16"
```

## Verification

```bash
# Check operator
kubectl get pods -n postgres-operator

# Check CRDs
kubectl get crd | grep postgres
```

## ArgoCD Compatibility

This chart is fully compatible with ArgoCD:
- Uses upstream Helm chart as dependency
- No manual kubectl commands required
- Declarative configuration
