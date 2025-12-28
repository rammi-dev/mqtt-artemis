#!/bin/bash
# =============================================================================
# Modular GKE Deployment Script
# =============================================================================
# Deploy GKE cluster and applications in stages
#
# Usage:
#   ./scripts/deploy-gke.sh [command]
#
# Commands:
#   all              - Deploy everything (default)
#   terraform        - Create GKE cluster via Terraform
#   kubeconfig       - Configure kubectl
#   infrastructure   - Deploy cert-manager and ingress-nginx
#   cert-manager     - Deploy cert-manager only
#   ingress-nginx    - Deploy ingress-nginx only
#   analytics        - Deploy all analytics components
#   artemis          - Deploy Artemis MQTT only
#   clickhouse       - Deploy ClickHouse only
#   nifi             - Deploy Apache NiFi only
#   redis            - Deploy Redis only
#   dagster          - Deploy Dagster only
#   prometheus       - Deploy Prometheus only
#   grafana          - Deploy Grafana only
#   dashboard-api    - Deploy Dashboard API only
#   verify           - Verify deployment
#   destroy          - Destroy everything
#   help             - Show this help message
# =============================================================================

set -e  # Exit on error

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Help
# =============================================================================

show_help() {
    cat << EOF
${GREEN}GKE Deployment Script${NC}

${BLUE}Usage:${NC}
  ./scripts/deploy-gke.sh [command]

${BLUE}Commands:${NC}
  ${GREEN}all${NC}              Deploy everything (Terraform + Infrastructure + Analytics)
  ${GREEN}terraform${NC}        Create GKE cluster via Terraform
  ${GREEN}kubeconfig${NC}       Configure kubectl to connect to cluster
  
  ${CYAN}Infrastructure:${NC}
  ${GREEN}infrastructure${NC}   Deploy infrastructure (cert-manager + ingress-nginx)
  ${GREEN}cert-manager${NC}     Deploy cert-manager only
  ${GREEN}ingress-nginx${NC}    Deploy ingress-nginx only
  
  ${CYAN}Analytics (All):${NC}
  ${GREEN}analytics${NC}        Deploy all analytics components
  
  ${CYAN}Analytics (Individual):${NC}
  ${GREEN}artemis${NC}          Deploy Artemis MQTT broker
  ${GREEN}clickhouse${NC}       Deploy ClickHouse database
  ${GREEN}nifi${NC}             Deploy Apache NiFi
  ${GREEN}redis${NC}            Deploy Redis cache
  ${GREEN}dagster${NC}          Deploy Dagster orchestration
  ${GREEN}prometheus${NC}       Deploy Prometheus monitoring
  ${GREEN}grafana${NC}          Deploy Grafana dashboards
  ${GREEN}dashboard-api${NC}    Deploy Dashboard API
  
  ${CYAN}Utilities:${NC}
  ${GREEN}verify${NC}           Verify deployment status
  ${GREEN}destroy${NC}          Destroy all resources (Helm + Terraform)
  ${GREEN}help${NC}             Show this help message

${BLUE}Examples:${NC}
  # Full deployment
  ./scripts/deploy-gke.sh all

  # Step-by-step deployment
  ./scripts/deploy-gke.sh terraform
  ./scripts/deploy-gke.sh kubeconfig
  ./scripts/deploy-gke.sh infrastructure
  ./scripts/deploy-gke.sh analytics

  # Deploy individual analytics components
  ./scripts/deploy-gke.sh artemis
  ./scripts/deploy-gke.sh clickhouse
  ./scripts/deploy-gke.sh nifi
  ./scripts/deploy-gke.sh grafana

  # Verify deployment
  ./scripts/deploy-gke.sh verify

  # Cleanup
  ./scripts/deploy-gke.sh destroy

${BLUE}Deployment Flow:${NC}
  1. terraform       → Create GKE cluster
  2. kubeconfig      → Configure kubectl
  3. infrastructure  → Deploy cert-manager + ingress-nginx
  4. analytics       → Deploy all analytics components
     OR deploy individual components:
     - artemis, clickhouse, nifi, redis, dagster, prometheus, grafana, dashboard-api

EOF
}

# =============================================================================
# Terraform - Create GKE Cluster
# =============================================================================

deploy_terraform() {
    log_step "Creating GKE cluster via Terraform..."

    check_required_tools terraform

    cd terraform/gke

    # Check if terraform.tfvars exists
    if [ ! -f terraform.tfvars ]; then
        log_warn "terraform.tfvars not found. Creating from example..."
        cp terraform.tfvars.example terraform.tfvars
        log_error "Please edit terraform/gke/terraform.tfvars with your configuration and run this script again."
        exit 1
    fi

    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init

    # Plan
    log_info "Planning Terraform changes..."
    terraform plan -out=tfplan

    # Apply
    log_info "Applying Terraform changes..."
    terraform apply tfplan
    rm -f tfplan

    cd ../..

    log_success "GKE cluster created successfully"
}

# =============================================================================
# Configure kubectl
# =============================================================================

configure_kubeconfig() {
    log_step "Configuring kubectl..."

    check_required_tools kubectl

    # Get kubeconfig command
    KUBECONFIG_CMD=$(get_terraform_output "kubeconfig_command")

    # Execute kubeconfig command
    log_info "Running: $KUBECONFIG_CMD"
    eval "$KUBECONFIG_CMD"

    # Verify connection
    log_info "Verifying cluster connection..."
    kubectl cluster-info
    kubectl get nodes

    log_success "kubectl configured successfully"
}

# =============================================================================
# Deploy cert-manager
# =============================================================================

deploy_cert_manager() {
    log_step "Deploying cert-manager..."

    check_required_tools helm kubectl
    check_kubectl_context

    helm upgrade --install cert-manager charts/infrastructure/cert-manager/ \
        --namespace cert-manager \
        --create-namespace \
        --wait \
        --timeout 5m

    wait_for_pods "cert-manager" "app.kubernetes.io/name=cert-manager" 300

    log_success "cert-manager deployed successfully"
}

# =============================================================================
# Deploy ingress-nginx
# =============================================================================

deploy_ingress_nginx() {
    log_step "Deploying ingress-nginx..."

    check_required_tools helm kubectl
    check_kubectl_context

    # Get static IP
    INGRESS_IP=$(get_terraform_output "ingress_ip")
    log_info "Using static IP: $INGRESS_IP"

    helm upgrade --install ingress-nginx charts/infrastructure/ingress-nginx/ \
        --namespace ingress-nginx \
        --create-namespace \
        --set ingress-nginx.controller.service.loadBalancerIP=$INGRESS_IP \
        --wait \
        --timeout 5m

    wait_for_pods "ingress-nginx" "app.kubernetes.io/name=ingress-nginx" 300

    log_success "ingress-nginx deployed successfully"
}

# =============================================================================
# Deploy Infrastructure (cert-manager + ingress-nginx)
# =============================================================================

deploy_infrastructure() {
    log_step "Deploying infrastructure components..."

    deploy_cert_manager
    deploy_ingress_nginx

    log_success "Infrastructure deployed successfully"
}

# =============================================================================
# Deploy Analytics
# =============================================================================

deploy_analytics() {
    log_step "Deploying edge-analytics..."

    check_required_tools helm kubectl
    check_kubectl_context

    # Update Helm dependencies
    log_info "Updating Helm dependencies for edge-analytics..."
    cd charts/edge-analytics
    helm dependency update
    cd ../..

    # Get nip.io domain
    NIP_IO_DOMAIN=$(get_terraform_output "nip_io_domain")
    log_info "Using domain: $NIP_IO_DOMAIN"

    # Deploy edge-analytics
    helm upgrade --install edge-analytics charts/edge-analytics/ \
        --namespace edge \
        --create-namespace \
        --set ingress.domain=$NIP_IO_DOMAIN \
        --wait \
        --timeout 10m

    log_success "edge-analytics deployed successfully"
}

# =============================================================================
# Deploy Individual Analytics Components
# =============================================================================

deploy_component() {
    local component=$1
    local condition=$2
    
    log_step "Deploying $component..."

    check_required_tools helm kubectl
    check_kubectl_context

    # Update Helm dependencies if needed
    if [ ! -d "charts/edge-analytics/charts" ]; then
        log_info "Updating Helm dependencies..."
        cd charts/edge-analytics
        helm dependency update
        cd ../..
    fi

    # Get nip.io domain
    NIP_IO_DOMAIN=$(get_terraform_output "nip_io_domain" 2>/dev/null || echo "")

    # Deploy with specific component enabled
    helm upgrade --install edge-analytics charts/edge-analytics/ \
        --namespace edge \
        --create-namespace \
        --set ingress.domain=$NIP_IO_DOMAIN \
        --set $condition=true \
        --wait \
        --timeout 10m

    log_success "$component deployed successfully"
}

deploy_artemis() {
    deploy_component "Artemis MQTT" "artemis.operator.enabled"
}

deploy_clickhouse() {
    deploy_component "ClickHouse" "clickhouse.enabled"
}

deploy_nifi() {
    deploy_component "Apache NiFi" "nifikop.enabled,zookeeper.enabled"
}

deploy_redis() {
    deploy_component "Redis" "redis.enabled"
}

deploy_dagster() {
    deploy_component "Dagster" "dagster.enabled"
}

deploy_prometheus() {
    deploy_component "Prometheus" "prometheus.enabled"
}

deploy_grafana() {
    deploy_component "Grafana" "grafana.enabled"
}

deploy_dashboard_api() {
    log_step "Deploying Dashboard API..."

    check_required_tools kubectl
    check_kubectl_context

    # Check if CRDs directory exists
    if [ -d "charts/edge-analytics/crds" ]; then
        log_info "Applying Dashboard API CRDs..."
        kubectl apply -f charts/edge-analytics/crds/dashboard-api.yaml -n edge
        log_success "Dashboard API deployed successfully"
    else
        log_warn "Dashboard API CRDs not found in charts/edge-analytics/crds/"
    fi
}

# =============================================================================
# Verify Deployment
# =============================================================================

verify_deployment() {
    log_step "Verifying deployment..."

    check_required_tools kubectl
    check_kubectl_context

    print_section "Namespaces"
    kubectl get namespaces | grep -E "NAME|cert-manager|ingress-nginx|edge"

    print_section "Infrastructure Pods"
    kubectl get pods -n cert-manager
    kubectl get pods -n ingress-nginx

    print_section "Analytics Pods"
    kubectl get pods -n edge

    print_section "ClusterIssuers"
    kubectl get clusterissuers

    print_section "Ingress Resources"
    kubectl get ingress -A

    print_section "Services"
    kubectl get svc -n ingress-nginx
    kubectl get svc -n edge | head -10

    log_success "Verification complete"
}

# =============================================================================
# Destroy Everything
# =============================================================================

destroy_all() {
    log_step "Destroying all resources..."

    check_required_tools helm kubectl terraform

    if ! confirm_action "This will delete all Helm releases and the GKE cluster. Are you sure?"; then
        log_info "Aborted."
        exit 0
    fi

    # Delete Helm releases
    log_info "Deleting Helm releases..."
    helm uninstall edge-analytics -n edge 2>/dev/null || log_warn "edge-analytics not found"
    helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || log_warn "ingress-nginx not found"
    helm uninstall cert-manager -n cert-manager 2>/dev/null || log_warn "cert-manager not found"

    # Wait for resources to be cleaned up
    log_info "Waiting for resources to be cleaned up..."
    sleep 10

    # Destroy Terraform resources
    log_info "Destroying GKE cluster..."
    cd terraform/gke
    terraform destroy -auto-approve
    cd ../..

    log_success "All resources destroyed"
}

# =============================================================================
# Deploy All
# =============================================================================

deploy_all() {
    log_step "Starting full deployment..."

    deploy_terraform
    configure_kubeconfig
    deploy_infrastructure
    deploy_analytics

    # Show summary
    print_header "Deployment Complete!"

    CLUSTER_NAME=$(get_terraform_output "cluster_name")
    INGRESS_IP=$(get_terraform_output "ingress_ip")
    NIP_IO_DOMAIN=$(get_terraform_output "nip_io_domain")

    log_info "Cluster: $CLUSTER_NAME"
    log_info "Ingress IP: $INGRESS_IP"
    log_info "Domain: $NIP_IO_DOMAIN"
    echo ""
    log_info "Namespaces:"
    log_info "  - cert-manager: TLS certificate management"
    log_info "  - ingress-nginx: Ingress controller"
    log_info "  - edge: Analytics workloads"
    echo ""
    log_info "Access services (after DNS propagation):"
    echo "  https://grafana.$NIP_IO_DOMAIN"
    echo "  https://nifi.$NIP_IO_DOMAIN"
    echo "  https://dagster.$NIP_IO_DOMAIN"
    echo ""
    log_info "For detailed service URLs, run:"
    echo "  ./scripts/access-info.sh"
}

# =============================================================================
# Main
# =============================================================================

COMMAND=${1:-all}

case "$COMMAND" in
    all)
        deploy_all
        ;;
    terraform)
        deploy_terraform
        ;;
    kubeconfig)
        configure_kubeconfig
        ;;
    infrastructure)
        deploy_infrastructure
        ;;
    cert-manager)
        deploy_cert_manager
        ;;
    ingress-nginx)
        deploy_ingress_nginx
        ;;
    analytics)
        deploy_analytics
        ;;
    artemis)
        deploy_artemis
        ;;
    clickhouse)
        deploy_clickhouse
        ;;
    nifi)
        deploy_nifi
        ;;
    redis)
        deploy_redis
        ;;
    dagster)
        deploy_dagster
        ;;
    prometheus)
        deploy_prometheus
        ;;
    grafana)
        deploy_grafana
        ;;
    dashboard-api)
        deploy_dashboard_api
        ;;
    verify)
        verify_deployment
        ;;
    destroy)
        destroy_all
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
