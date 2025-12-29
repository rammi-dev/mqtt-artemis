# Keycloak Database

PostgreSQL database for Keycloak, managed by Zalando Postgres Operator.

## Prerequisites

- Postgres Operator must be installed first

## Installation

```bash
./scripts/deploy-gke.sh keycloak-db
```

## What Gets Created

- PostgreSQL cluster with 1 instance (configurable)
- Database: `keycloak`
- User: `keycloak` (with superuser privileges)
- Secret: `keycloak.keycloak-db.credentials.postgresql.acid.zalan.do`

## Accessing Credentials

The operator automatically creates a secret with database credentials:

```bash
kubectl get secret keycloak.keycloak-db.credentials.postgresql.acid.zalan.do -n keycloak -o yaml
```

## Connection Details

- **Host:** `keycloak-db.keycloak.svc.cluster.local`
- **Port:** `5432`
- **Database:** `keycloak`
- **User:** `keycloak`
- **Password:** Stored in secret (key: `password`)

## Verification

```bash
# Check PostgreSQL cluster
kubectl get postgresql -n keycloak

# Check pods
kubectl get pods -n keycloak -l application=spilo

# Check secret
kubectl get secret -n keycloak | grep keycloak-db
```
