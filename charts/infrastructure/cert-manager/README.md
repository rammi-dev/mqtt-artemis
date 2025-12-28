# cert-manager Deployment

This directory contains the Helm chart for deploying cert-manager to GKE.

## Overview

cert-manager is split into two separate charts for proper CRD initialization:

1. **cert-manager** - Core cert-manager installation with CRDs
2. **cert-manager-issuers** - ClusterIssuers (deployed after cert-manager)

This separation ensures ClusterIssuers are created only after cert-manager CRDs are fully ready.

## Components

### cert-manager Chart

**Location:** `charts/infrastructure/cert-manager/`

**Includes:**
- cert-manager controller
- cert-manager webhook
- cert-manager cainjector
- Custom Resource Definitions (CRDs)

**Resources:**
- CPU: 100m request, 200m limit
- Memory: 160Mi request, 320Mi limit

### cert-manager-issuers Chart

**Location:** `charts/infrastructure/cert-manager-issuers/`

**Includes:**
- `letsencrypt-prod` - Production Let's Encrypt issuer
- `letsencrypt-staging` - Staging Let's Encrypt issuer
- `selfsigned-issuer` - Self-signed certificate issuer

## Deployment

### Using the Deploy Script

**Deploy cert-manager only:**
```bash
./scripts/deploy-gke.sh cert-manager
```

**Deploy ClusterIssuers only:**
```bash
./scripts/deploy-gke.sh cert-manager-issuers
```

**Deploy both (part of infrastructure):**
```bash
./scripts/deploy-gke.sh infrastructure
```

### Manual Deployment

**Step 1: Deploy cert-manager**
```bash
helm upgrade --install cert-manager charts/infrastructure/cert-manager/ \
  --namespace cert-manager \
  --create-namespace \
  --wait \
  --timeout 5m
```

**Step 2: Deploy ClusterIssuers (wait 5 seconds for CRDs)**
```bash
sleep 5
helm upgrade --install cert-manager-issuers charts/infrastructure/cert-manager-issuers/ \
  --namespace cert-manager \
  --wait \
  --timeout 2m
```

## Configuration

### Email Address

Update your email in `charts/infrastructure/cert-manager-issuers/values.yaml`:

```yaml
letsencrypt:
  email: your-email@example.com  # ← Change this!
```

This email is used by Let's Encrypt for:
- Certificate expiration notices
- Important security notifications
- Account recovery

### ClusterIssuer Selection

Enable/disable issuers in `values.yaml`:

```yaml
letsencrypt:
  production:
    enabled: true   # Real, trusted certificates
  
  staging:
    enabled: true   # Test certificates (not trusted)
  
  selfsigned:
    enabled: true   # Self-signed certificates
```

## Usage

### In Ingress Resources

**Production (trusted certificates):**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
```

**Staging (testing):**
```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
```

**Self-signed:**
```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "selfsigned-issuer"
```

## Verification

**Check cert-manager pods:**
```bash
kubectl get pods -n cert-manager
```

Expected output:
```
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-xxx                           1/1     Running   0          2m
cert-manager-cainjector-xxx                1/1     Running   0          2m
cert-manager-webhook-xxx                   1/1     Running   0          2m
```

**Check ClusterIssuers:**
```bash
kubectl get clusterissuers
```

Expected output:
```
NAME                  READY   AGE
letsencrypt-prod      True    1m
letsencrypt-staging   True    1m
selfsigned-issuer     True    1m
```

**Check certificate:**
```bash
kubectl get certificate -A
kubectl describe certificate <name> -n <namespace>
```

## Troubleshooting

### ClusterIssuers Not Ready

**Problem:** ClusterIssuers show `READY: False`

**Solution:**
```bash
# Check issuer status
kubectl describe clusterissuer letsencrypt-prod

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

### Certificate Not Issued

**Problem:** Certificate stuck in `Pending` state

**Solution:**
```bash
# Check certificate status
kubectl describe certificate <name> -n <namespace>

# Check certificate request
kubectl get certificaterequest -n <namespace>
kubectl describe certificaterequest <name> -n <namespace>

# Check challenges (for Let's Encrypt)
kubectl get challenges -A
kubectl describe challenge <name> -n <namespace>
```

### Let's Encrypt Rate Limits

**Problem:** Hit Let's Encrypt rate limits (50 certs/week per domain)

**Solution:**
1. Use `letsencrypt-staging` for testing (no limits)
2. Use your own domain (not nip.io)
3. Wait for rate limit window to reset (7 days)

## Let's Encrypt Rate Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Certificates per domain | 50/week | Per registered domain |
| Duplicate certificates | 5/week | Same exact domains |
| Failed validations | 5/hour | Failed ACME challenges |
| Renewals | Unlimited | Exempt from limits |

**For nip.io:** You share the 50/week limit with all nip.io users!

## ArgoCD Compatibility

This setup is fully compatible with ArgoCD:

```yaml
# ArgoCD Application for cert-manager
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
spec:
  source:
    path: charts/infrastructure/cert-manager
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
---
# ArgoCD Application for ClusterIssuers
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager-issuers
spec:
  source:
    path: charts/infrastructure/cert-manager-issuers
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    syncWave: "1"  # Deploy after cert-manager
```

## Resources

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [ACME Challenge Types](https://cert-manager.io/docs/configuration/acme/)
