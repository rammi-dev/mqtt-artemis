# =============================================================================
# cert-manager + Let's Encrypt Configuration
# =============================================================================

# Namespace for cert-manager
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [google_container_node_pool.primary_nodes]
}

# Install cert-manager via Helm
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  create_namespace = false

  # Install CRDs
  set {
    name  = "installCRDs"
    value = "true"
  }

  # Resource limits for cost optimization
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }

  # Webhook resources
  set {
    name  = "webhook.resources.requests.cpu"
    value = "25m"
  }

  set {
    name  = "webhook.resources.requests.memory"
    value = "32Mi"
  }

  # CA Injector resources
  set {
    name  = "cainjector.resources.requests.cpu"
    value = "25m"
  }

  set {
    name  = "cainjector.resources.requests.memory"
    value = "64Mi"
  }

  # Tolerate spot VMs
  dynamic "set" {
    for_each = var.use_spot_vms ? [1] : []
    content {
      name  = "tolerations[0].key"
      value = "cloud.google.com/gke-spot"
    }
  }

  dynamic "set" {
    for_each = var.use_spot_vms ? [1] : []
    content {
      name  = "tolerations[0].operator"
      value = "Equal"
    }
  }

  dynamic "set" {
    for_each = var.use_spot_vms ? [1] : []
    content {
      name  = "tolerations[0].value"
      value = "true"
    }
  }

  dynamic "set" {
    for_each = var.use_spot_vms ? [1] : []
    content {
      name  = "tolerations[0].effect"
      value = "NoSchedule"
    }
  }

  depends_on = [google_container_node_pool.primary_nodes]
}

# Wait for cert-manager CRDs to be ready
resource "time_sleep" "wait_for_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# =============================================================================
# Let's Encrypt ClusterIssuers
# =============================================================================

# Let's Encrypt Production Issuer
resource "kubectl_manifest" "letsencrypt_prod" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: letsencrypt-prod-account-key
        solvers:
          - http01:
              ingress:
                class: nginx
                serviceType: ClusterIP
  YAML

  depends_on = [time_sleep.wait_for_cert_manager]
}

# Let's Encrypt Staging Issuer (for testing - no rate limits)
resource "kubectl_manifest" "letsencrypt_staging" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-staging
    spec:
      acme:
        server: https://acme-staging-v02.api.letsencrypt.org/directory
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: letsencrypt-staging-account-key
        solvers:
          - http01:
              ingress:
                class: nginx
                serviceType: ClusterIP
  YAML

  depends_on = [time_sleep.wait_for_cert_manager]
}

# Self-signed issuer for internal services
resource "kubectl_manifest" "selfsigned_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: selfsigned-issuer
    spec:
      selfSigned: {}
  YAML

  depends_on = [time_sleep.wait_for_cert_manager]
}

# =============================================================================
# Outputs
# =============================================================================

output "cert_manager_namespace" {
  description = "cert-manager namespace"
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

output "cluster_issuers" {
  description = "Available ClusterIssuers"
  value = [
    "letsencrypt-prod (production certificates)",
    "letsencrypt-staging (testing - no rate limits)",
    "selfsigned-issuer (internal services)"
  ]
}
