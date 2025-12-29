# Keycloak Deployment Fix - Summary

## Issue

When deploying Keycloak using `./scripts/deploy-gke.sh keycloak`, the Helm upgrade failed with:

```
Error: UPGRADE FAILED: Unable to continue with update: Certificate "keycloak-tls" in namespace "keycloak" exists and cannot be imported into the current release: invalid ownership metadata; annotation validation error: missing key "meta.helm.sh/release-name": must be set to "keycloak"
```

## Root Cause

The deployment had **two conflicting approaches** for managing the Ingress resource:

1. **Keycloak Operator** - Configured to create and manage its own Ingress (`ingress.enabled: true` in Keycloak CR)
2. **Helm Chart** - Had a separate `ingress.yaml` template to create the Ingress

This caused:
- The operator created the Ingress first
- Helm tried to take ownership but couldn't due to missing annotations
- The Certificate resource was created by cert-manager via the Ingress annotation, but without Helm ownership
- Conflicts and errors on subsequent deployments

## Solution

**Disabled operator's Ingress management** and let Helm manage everything:

### 1. Updated Keycloak CR (`keycloak.yaml`)
```yaml
ingress:
  enabled: false  # ← Disabled operator's Ingress creation
```

### 2. Created Helm-managed Ingress (`ingress.yaml`)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - keycloak.<INGRESS_IP>.nip.io
    secretName: keycloak-tls  # ← TLS section for cert-manager
  rules:
  - host: keycloak.<INGRESS_IP>.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak-service
            port:
              number: 8080
```

### 3. Created Certificate Resource (`certificate.yaml`)
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: keycloak-tls
  namespace: keycloak
spec:
  secretName: keycloak-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - keycloak.<INGRESS_IP>.nip.io
```

## Benefits

✅ **Clean Ownership** - All resources managed by Helm
✅ **Proper TLS** - Certificate managed by cert-manager
✅ **Repeatable** - Works from scratch every time
✅ **No Conflicts** - Operator and Helm don't fight over resources
✅ **ArgoCD Compatible** - Declarative and GitOps-friendly

## Files Changed

1. [`charts/infrastructure/keycloak/templates/keycloak.yaml`](file:///home/rami/Work/artemis/charts/infrastructure/keycloak/templates/keycloak.yaml) - Disabled operator Ingress
2. [`charts/infrastructure/keycloak/templates/ingress.yaml`](file:///home/rami/Work/artemis/charts/infrastructure/keycloak/templates/ingress.yaml) - Created Helm-managed Ingress
3. [`charts/infrastructure/keycloak/templates/certificate.yaml`](file:///home/rami/Work/artemis/charts/infrastructure/keycloak/templates/certificate.yaml) - Created Certificate resource
4. [`charts/infrastructure/keycloak/README.md`](file:///home/rami/Work/artemis/charts/infrastructure/keycloak/README.md) - Updated documentation
5. [`INFRASTRUCTURE.md`](file:///home/rami/Work/artemis/INFRASTRUCTURE.md) - Added Keycloak to architecture
6. [`test/nginx-test.yaml`](file:///home/rami/Work/artemis/test/nginx-test.yaml) - Fixed test page URLs

## Verification

```bash
# Check all resources are created
kubectl get ingress,certificate,secret -n keycloak | grep keycloak-tls

# Expected output:
# ingress.networking.k8s.io/keycloak-ingress   nginx   keycloak.35.206.88.67.nip.io   35.206.88.67   80, 443
# certificate.cert-manager.io/keycloak-tls     True    keycloak-tls
# secret/keycloak-tls                          kubernetes.io/tls    2

# Check Keycloak status
kubectl get keycloak keycloak -n keycloak -o jsonpath='{.status.conditions}' | jq .

# Expected: Ready=True, HasErrors=False

# Test access
curl -k https://keycloak.35.206.88.67.nip.io/
# Expected: HTTP 200
```

## Deployment

The fix is now integrated into the deployment script:

```bash
./scripts/deploy-gke.sh keycloak
```

This will:
1. Deploy Postgres Operator (if not already deployed)
2. Deploy Keycloak Database
3. Deploy Keycloak Operator + CRDs
4. Deploy Keycloak Instance
5. Create Helm-managed Ingress
6. Create Certificate via cert-manager

Access Keycloak at: `https://keycloak.<INGRESS_IP>.nip.io`
