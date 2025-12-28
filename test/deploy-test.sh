#!/bin/bash
# =============================================================================
# Test Application Deployment Script
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# =============================================================================
# Deploy Test App
# =============================================================================

deploy_test() {
    log_step "Deploying test nginx application..."
    
    # Delete existing if present
    kubectl delete namespace test --ignore-not-found=true
    
    log_info "Waiting for namespace to be fully deleted..."
    sleep 5
    
    # Deploy
    kubectl apply -f "$SCRIPT_DIR/nginx-test.yaml"
    
    log_info "Waiting for pod to be ready..."
    kubectl wait --for=condition=ready pod -l app=nginx-test -n test --timeout=60s
    
    log_info "Waiting for certificate to be issued (this may take up to 2 minutes)..."
    
    # Wait for certificate
    for i in {1..24}; do
        CERT_READY=$(kubectl get certificate nginx-test-tls -n test -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
        if [ "$CERT_READY" = "True" ]; then
            log_success "Certificate issued successfully!"
            break
        fi
        echo -n "."
        sleep 5
    done
    echo ""
    
    # Get ingress IP
    INGRESS_IP=$(kubectl get ingress nginx-test -n test -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    log_success "Test application deployed!"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Test Application Ready!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "  ${CYAN}URL:${NC} https://test.35-206-88-67.nip.io"
    echo -e "  ${CYAN}IP:${NC}  $INGRESS_IP"
    echo ""
    echo -e "${YELLOW}Note:${NC} It may take a few minutes for DNS and certificate to propagate."
    echo ""
}

# =============================================================================
# Check Status
# =============================================================================

check_status() {
    log_step "Checking test application status..."
    echo ""
    
    echo -e "${CYAN}Pods:${NC}"
    kubectl get pods -n test
    echo ""
    
    echo -e "${CYAN}Service:${NC}"
    kubectl get svc -n test
    echo ""
    
    echo -e "${CYAN}Ingress:${NC}"
    kubectl get ingress -n test
    echo ""
    
    echo -e "${CYAN}Certificate:${NC}"
    kubectl get certificate -n test
    echo ""
    
    CERT_READY=$(kubectl get certificate nginx-test-tls -n test -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    
    if [ "$CERT_READY" = "True" ]; then
        log_success "Certificate is ready!"
    else
        log_warn "Certificate is not ready yet. Status: $CERT_READY"
        echo ""
        echo "Check certificate details:"
        echo "  kubectl describe certificate nginx-test-tls -n test"
    fi
}

# =============================================================================
# Delete Test App
# =============================================================================

delete_test() {
    log_step "Deleting test application..."
    kubectl delete namespace test --ignore-not-found=true
    log_success "Test application deleted"
}

# =============================================================================
# Show Help
# =============================================================================

show_help() {
    echo "Test Application Deployment Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  deploy   - Deploy test application (default)"
    echo "  status   - Check test application status"
    echo "  delete   - Delete test application"
    echo "  help     - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy"
    echo "  $0 status"
    echo "  $0 delete"
}

# =============================================================================
# Main
# =============================================================================

COMMAND=${1:-deploy}

case $COMMAND in
    deploy)
        deploy_test
        ;;
    status)
        check_status
        ;;
    delete)
        delete_test
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
