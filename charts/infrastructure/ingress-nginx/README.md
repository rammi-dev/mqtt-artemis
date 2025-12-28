# ingress-nginx Helm Chart

This chart deploys the NGINX Ingress Controller for GKE with static IP support.

## What This Deploys

- **NGINX Ingress Controller**: Routes external HTTP/HTTPS traffic to services
- **LoadBalancer Service**: With static IP address
- **Metrics**: Prometheus metrics endpoint

## Installation

```bash
# Get static IP from Terraform
INGRESS_IP=$(cd terraform/gke && terraform output -raw ingress_ip)

# Deploy ingress-nginx
helm upgrade --install ingress-nginx charts/infrastructure/ingress-nginx/ \
  --namespace ingress-nginx \
  --create-namespace \
  --set ingress-nginx.controller.service.loadBalancerIP=$INGRESS_IP \
  --wait
```

## Configuration

### Static IP

The static IP must be set during installation:

```bash
--set ingress-nginx.controller.service.loadBalancerIP=<YOUR_STATIC_IP>
```

### Custom Configuration

Edit `values.yaml` to customize:

```yaml
ingress-nginx:
  controller:
    replicaCount: 2  # Increase for HA
    
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
    
    config:
      proxy-body-size: "100m"  # Max upload size
      ssl-protocols: "TLSv1.2 TLSv1.3"
```

## Usage

### Basic Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: myapp.34.118.224.103.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

### With TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: selfsigned-issuer
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - myapp.34.118.224.103.nip.io
      secretName: myapp-tls
  rules:
    - host: myapp.34.118.224.103.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## Verification

```bash
# Check ingress controller pods
kubectl get pods -n ingress-nginx

# Check LoadBalancer service
kubectl get svc -n ingress-nginx

# Check ingress resources
kubectl get ingress -A

# Test ingress
curl -k https://myapp.<INGRESS_IP>.nip.io
```

## Troubleshooting

```bash
# Check controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Describe ingress
kubectl describe ingress <ingress-name> -n <namespace>

# Check service endpoints
kubectl get endpoints -n <namespace>
```

## Metrics

Prometheus metrics are available at:
```
http://<controller-pod-ip>:10254/metrics
```

Enable ServiceMonitor for Prometheus Operator:
```yaml
ingress-nginx:
  controller:
    metrics:
      serviceMonitor:
        enabled: true
```
