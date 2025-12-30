#!/bin/bash
# =============================================================================
# Deploy IoT Load Tester
# =============================================================================
# Deploys IoT Load Tester to GKE using Helm
# Automatically detects ingress IP and configures domain
#
# Usage:
#   ./scripts/iot-load-tester/deploy.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Check required tools
check_required_tools kubectl helm

# Check kubectl context
check_kubectl_context

# Configuration
RELEASE_NAME="iot-load-tester"
NAMESPACE="test"
CHART_DIR="$SCRIPT_DIR/../../charts/iot-load-tester"

# Image configuration
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION="us-central1"
REGISTRY="$REGION-docker.pkg.dev"
IMAGE_REPO="$REGISTRY/$PROJECT_ID/iot-load-tester/iot-load-tester"
IMAGE_TAG="latest"

print_header "Deploying IoT Load Tester"

# Get ingress IP
log_step "Getting ingress IP..."
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$INGRESS_IP" ]; then
    log_error "Could not get ingress IP. Is ingress-nginx deployed?"
    exit 1
fi

DOMAIN="${INGRESS_IP}.nip.io"
log_info "Ingress IP: $INGRESS_IP"
log_info "Domain: $DOMAIN"

# Ensure namespace exists
log_step "Ensuring namespace exists..."
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

# Configure Docker authentication (in case nodes need to pull)
log_step "Configuring Docker authentication..."
gcloud auth configure-docker "$REGISTRY" --quiet

# Deploy with Helm
log_step "Deploying with Helm..."
helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    --set image.repository="$IMAGE_REPO" \
    --set image.tag="$IMAGE_TAG" \
    --set image.pullPolicy="Always" \
    --set domain="$DOMAIN" \
    --wait \
    --timeout 5m

# Force restart to pull latest image
log_step "Restarting deployment to pull latest image..."
kubectl rollout restart deployment/"$RELEASE_NAME" -n "$NAMESPACE"

# Wait for pod to be ready
log_step "Waiting for pod to be ready..."
kubectl rollout status deployment/"$RELEASE_NAME" -n "$NAMESPACE" --timeout=120s

# Get pod status
log_step "Checking pod status..."
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=iot-load-tester

echo ""
print_header "Deployment Complete!"

echo ""
echo "Access URLs:"
echo "  OpenAPI Docs: https://loadtest.$DOMAIN/docs"
echo "  Redoc:        https://loadtest.$DOMAIN/redoc"
echo "  Health:       https://loadtest.$DOMAIN/health"
echo "  Metrics:      https://loadtest.$DOMAIN/metrics"
echo ""
echo "Port Forward (local access):"
echo "  kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME 8090:8090"
echo "  Access: http://localhost:8090/docs"
echo ""
log_success "IoT Load Tester deployed successfully!"
