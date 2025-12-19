# =============================================================================
# NGINX Ingress Controller with nip.io Support
# =============================================================================

# Namespace for ingress-nginx
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [google_container_node_pool.primary_nodes]
}

# Install ingress-nginx via Helm
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_version
  namespace        = kubernetes_namespace.ingress_nginx.metadata[0].name
  create_namespace = false

  # Use our static IP
  set {
    name  = "controller.service.loadBalancerIP"
    value = google_compute_address.ingress_ip.address
  }

  # Standard network tier (cheaper)
  set {
    name  = "controller.service.annotations.cloud\\.google\\.com/network-tier"
    value = "Standard"
  }

  # Enable proxy protocol for real client IPs
  set {
    name  = "controller.config.use-proxy-protocol"
    value = "false"
  }

  # Resource limits for cost optimization
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "256Mi"
  }

  # Single replica for cost (increase for HA)
  set {
    name  = "controller.replicaCount"
    value = "1"
  }

  # Enable metrics for Prometheus
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = "false"  # Enable if using Prometheus Operator
  }

  # Default SSL certificate (optional)
  set {
    name  = "controller.extraArgs.default-ssl-certificate"
    value = "edge/wildcard-tls"  # Will be created by cert-manager
  }

  # Tolerate spot VMs
  dynamic "set" {
    for_each = var.use_spot_vms ? [1] : []
    content {
      name  = "controller.tolerations[0].key"
      value = "cloud.google.com/gke-spot"
    }
  }

  dynamic "set" {
    for_each = var.use_spot_vms ? [1] : []
    content {
      name  = "controller.tolerations[0].operator"
      value = "Equal"
    }
  }

  dynamic "set" {
    for_each = var.use_spot_vms ? [1] : []
    content {
      name  = "controller.tolerations[0].value"
      value = "true"
    }
  }

  dynamic "set" {
    for_each = var.use_spot_vms ? [1] : []
    content {
      name  = "controller.tolerations[0].effect"
      value = "NoSchedule"
    }
  }

  depends_on = [
    google_container_node_pool.primary_nodes,
    google_compute_address.ingress_ip
  ]
}

# Wait for ingress controller to be ready
resource "time_sleep" "wait_for_ingress" {
  depends_on      = [helm_release.ingress_nginx]
  create_duration = "60s"
}

# =============================================================================
# Wildcard Certificate for nip.io (Self-signed)
# Note: Let's Encrypt doesn't support nip.io directly due to rate limits
# For production, use a real domain with DNS-01 challenge
# =============================================================================

resource "kubectl_manifest" "wildcard_certificate" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: wildcard-tls
      namespace: edge
    spec:
      secretName: wildcard-tls
      issuerRef:
        name: selfsigned-issuer
        kind: ClusterIssuer
      commonName: "*.${google_compute_address.ingress_ip.address}.nip.io"
      dnsNames:
        - "*.${google_compute_address.ingress_ip.address}.nip.io"
        - "${google_compute_address.ingress_ip.address}.nip.io"
  YAML

  depends_on = [
    time_sleep.wait_for_cert_manager,
    kubectl_manifest.selfsigned_issuer,
    kubernetes_namespace.edge
  ]
}

# =============================================================================
# Edge namespace (for application deployment)
# =============================================================================

resource "kubernetes_namespace" "edge" {
  metadata {
    name = "edge"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [google_container_node_pool.primary_nodes]
}

# =============================================================================
# Sample Ingress Resources for nip.io
# =============================================================================

# Grafana Ingress
resource "kubectl_manifest" "grafana_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: grafana-ingress
      namespace: edge
      annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: selfsigned-issuer
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
    spec:
      tls:
        - hosts:
            - grafana.${google_compute_address.ingress_ip.address}.nip.io
          secretName: grafana-tls
      rules:
        - host: grafana.${google_compute_address.ingress_ip.address}.nip.io
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: edge-analytics-grafana
                    port:
                      number: 80
  YAML

  depends_on = [
    time_sleep.wait_for_ingress,
    kubernetes_namespace.edge
  ]
}

# NiFi Ingress
resource "kubectl_manifest" "nifi_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: nifi-ingress
      namespace: edge
      annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: selfsigned-issuer
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
        nginx.ingress.kubernetes.io/proxy-body-size: "100m"
        nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
        nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    spec:
      tls:
        - hosts:
            - nifi.${google_compute_address.ingress_ip.address}.nip.io
          secretName: nifi-tls
      rules:
        - host: nifi.${google_compute_address.ingress_ip.address}.nip.io
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: edge-nifi
                    port:
                      number: 8080
  YAML

  depends_on = [
    time_sleep.wait_for_ingress,
    kubernetes_namespace.edge
  ]
}

# Dagster Ingress
resource "kubectl_manifest" "dagster_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: dagster-ingress
      namespace: edge
      annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: selfsigned-issuer
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
    spec:
      tls:
        - hosts:
            - dagster.${google_compute_address.ingress_ip.address}.nip.io
          secretName: dagster-tls
      rules:
        - host: dagster.${google_compute_address.ingress_ip.address}.nip.io
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: edge-analytics-dagster-webserver
                    port:
                      number: 80
  YAML

  depends_on = [
    time_sleep.wait_for_ingress,
    kubernetes_namespace.edge
  ]
}

# Dashboard API Ingress
resource "kubectl_manifest" "dashboard_api_ingress" {
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: dashboard-api-ingress
      namespace: edge
      annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: selfsigned-issuer
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
        nginx.ingress.kubernetes.io/cors-allow-origin: "*"
        nginx.ingress.kubernetes.io/enable-cors: "true"
    spec:
      tls:
        - hosts:
            - api.${google_compute_address.ingress_ip.address}.nip.io
          secretName: api-tls
      rules:
        - host: api.${google_compute_address.ingress_ip.address}.nip.io
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: dashboard-api
                    port:
                      number: 8000
  YAML

  depends_on = [
    time_sleep.wait_for_ingress,
    kubernetes_namespace.edge
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "ingress_nginx_namespace" {
  description = "ingress-nginx namespace"
  value       = kubernetes_namespace.ingress_nginx.metadata[0].name
}

output "service_urls" {
  description = "Service URLs (nip.io)"
  value = {
    grafana       = "https://grafana.${google_compute_address.ingress_ip.address}.nip.io"
    nifi          = "https://nifi.${google_compute_address.ingress_ip.address}.nip.io"
    dagster       = "https://dagster.${google_compute_address.ingress_ip.address}.nip.io"
    dashboard_api = "https://api.${google_compute_address.ingress_ip.address}.nip.io"
  }
}
