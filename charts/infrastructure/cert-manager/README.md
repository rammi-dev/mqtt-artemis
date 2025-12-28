# cert-manager Helm Chart

This chart deploys cert-manager with pre-configured ClusterIssuers for automatic TLS certificate management.

## What This Deploys

- **cert-manager**: Kubernetes add-on to automate TLS certificate management
- **ClusterIssuers**:
  - `letsencrypt-prod`: Production Let's Encrypt certificates
  - `letsencrypt-staging`: Staging Let's Encrypt certificates (for testing)
  - `selfsigned-issuer`: Self-signed certificates (for nip.io and internal services)

## Installation

```bash
helm upgrade --install cert-manager charts/infrastructure/cert-manager/ \
  --namespace cert-manager \
  --create-namespace \
  --wait
```

## Configuration

Edit `values.yaml` to customize:

```yaml
letsencrypt:
  email: your-email@example.com  # Required for Let's Encrypt
  
  production:
    enabled: true
  
  staging:
    enabled: true  # Recommended for testing
  
  selfsigned:
    enabled: true  # For nip.io domains
```

## Usage in Ingress

### Let's Encrypt Production

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - myapp.example.com
      secretName: myapp-tls
  rules:
    - host: myapp.example.com
      # ...
```

### Self-Signed (for nip.io)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-issuer
spec:
  tls:
    - hosts:
        - myapp.34.118.224.103.nip.io
      secretName: myapp-tls
  rules:
    - host: myapp.34.118.224.103.nip.io
      # ...
```

## Verification

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check ClusterIssuers
kubectl get clusterissuers

# Check certificates
kubectl get certificates -A
```

## Troubleshooting

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Describe a certificate
kubectl describe certificate <cert-name> -n <namespace>

# Check certificate request
kubectl get certificaterequest -n <namespace>
```
