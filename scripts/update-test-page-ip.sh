#!/bin/bash
# =============================================================================
# Update Test Page IP
# =============================================================================
# Updates the test page with the current ingress IP after cluster restart
#
# Usage:
#   ./scripts/update-test-page-ip.sh
# =============================================================================

set -e

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

check_required_tools kubectl

log_step "Updating test page with current Ingress IP..."

# Get current ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$INGRESS_IP" ]; then
    log_error "Could not get Ingress IP. Is ingress-nginx deployed?"
    exit 1
fi

log_info "Current Ingress IP: $INGRESS_IP"

# The test page now uses JavaScript to dynamically construct URLs
# No manual updates needed!

log_success "Test page is already configured to use dynamic URLs"
log_info "Service links will automatically use the current domain"
log_info ""
log_info "Access the test page at: https://$INGRESS_IP.nip.io"
