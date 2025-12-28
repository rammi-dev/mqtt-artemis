#!/bin/bash
# Modular deployment script for Edge Analytics Platform
# Each component can be deployed separately or all at once

set -e

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CHART_DIR="$PROJECT_ROOT/charts/edge-analytics"
CRDS_DIR="$CHART_DIR/crds"

NAMESPACE="edge"
RELEASE_NAME="edge-analytics"
TIMEOUT="10m"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Component order (dependency chain)
COMPONENTS=(
    "terraform"
    "namespace"
    "cert-manager"
    "helm-deps"
    "zookeeper"
    "artemis"
    "redis"
    "clickhouse"
    "nifi"
    "dagster"
    "prometheus"
    "grafana"
    "dashboard-api"
    "producer"
    "flutter-dashboard"
)

TERRAFORM_DIR="$PROJECT_ROOT/terraform/gke"

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
}

wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-120}
    
    log_info "Waiting for pods with label '$label' in namespace '$namespace'..."
    kubectl wait --for=condition=ready pod -l "$label" -n "$namespace" --timeout="${timeout}s" 2>/dev/null || {
        log_warn "Timeout waiting for pods, continuing..."
    }
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is required but not installed."
        exit 1
    fi
}

# ============================================================================
# Component Deployment Functions
# ============================================================================

deploy_terraform() {
    log_header "Provisioning GKE Cluster via Terraform"
    
    if [ ! -d "$TERRAFORM_DIR" ]; then
        log_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    # Check for terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is required but not installed."
        log_info "Install: https://developer.hashicorp.com/terraform/downloads"
        exit 1
    fi
    
    cd "$TERRAFORM_DIR"
    
    # Check for tfvars
    if [ ! -f "terraform.tfvars" ]; then
        if [ -f "terraform.tfvars.example" ]; then
            log_warn "terraform.tfvars not found. Creating from example..."
            cp terraform.tfvars.example terraform.tfvars
            log_info "Please edit $TERRAFORM_DIR/terraform.tfvars with your settings"
            log_info "Required: project_id, letsencrypt_email"
            read -p "Press Enter after editing terraform.tfvars..."
        else
            log_error "No terraform.tfvars or example found"
            exit 1
        fi
    fi
    
    log_info "Initializing Terraform..."
    terraform init
    
    log_info "Planning infrastructure..."
    terraform plan -out=tfplan
    
    read -p "Apply this plan? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Applying Terraform..."
        terraform apply tfplan
        
        log_info "Configuring kubectl..."
        eval "$(terraform output -raw kubeconfig_command)"
        
        log_success "GKE cluster provisioned"
        log_info "Ingress IP: $(terraform output -raw ingress_ip)"
        log_info "nip.io domain: $(terraform output -raw nip_io_domain)"
    else
        log_warn "Terraform apply cancelled"
    fi
    
    cd "$PROJECT_ROOT"
}

deploy_namespace() {
    log_header "Creating Namespace: $NAMESPACE"
    
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace clickhouse --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace nifi --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Namespaces created"
}

deploy_cert_manager() {
    log_header "Installing cert-manager"
    
    # Check if already installed
    if kubectl get namespace cert-manager &>/dev/null; then
        log_info "cert-manager namespace exists, checking pods..."
        if kubectl get pods -n cert-manager -l app=cert-manager --no-headers 2>/dev/null | grep -q Running; then
            log_success "cert-manager already running, skipping"
            return 0
        fi
    fi
    
    log_info "Installing cert-manager v1.13.0..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    wait_for_pods "cert-manager" "app.kubernetes.io/instance=cert-manager" 180
    
    log_success "cert-manager installed"
}

deploy_helm_deps() {
    log_header "Updating Helm Dependencies"
    
    cd "$CHART_DIR"
    
    log_info "Downloading chart dependencies..."
    helm dependency update
    
    cd "$PROJECT_ROOT"
    
    log_success "Helm dependencies updated"
}

deploy_zookeeper() {
    log_header "Deploying Zookeeper"
    
    log_info "Installing Zookeeper (required for NiFi)..."
    helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set artemis.enabled=false \
        --set clickhouse.enabled=false \
        --set zookeeper.enabled=true \
        --set nifikop.enabled=false \
        --set redis.enabled=false \
        --set dagster.enabled=false \
        --set prometheus.enabled=false \
        --set grafana.enabled=false \
        --wait \
        --timeout="$TIMEOUT"
    
    wait_for_pods "$NAMESPACE" "app.kubernetes.io/name=zookeeper" 180
    
    log_success "Zookeeper deployed"
}

deploy_artemis() {
    log_header "Deploying Artemis MQTT Broker"
    
    log_info "Installing Artemis..."
    helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set artemis.enabled=true \
        --set clickhouse.enabled=false \
        --set zookeeper.enabled=true \
        --set nifikop.enabled=false \
        --set redis.enabled=false \
        --set dagster.enabled=false \
        --set prometheus.enabled=false \
        --set grafana.enabled=false \
        --wait \
        --timeout="$TIMEOUT"
    
    log_info "Waiting for Artemis pods..."
    sleep 10
    
    log_success "Artemis deployed"
}

deploy_redis() {
    log_header "Deploying Redis"
    
    log_info "Installing Redis cache (hot metrics, 15 min TTL)..."
    helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set artemis.enabled=true \
        --set clickhouse.enabled=false \
        --set zookeeper.enabled=true \
        --set nifikop.enabled=false \
        --set redis.enabled=true \
        --set dagster.enabled=false \
        --set prometheus.enabled=false \
        --set grafana.enabled=false \
        --wait \
        --timeout="$TIMEOUT"
    
    wait_for_pods "$NAMESPACE" "app.kubernetes.io/name=redis" 180
    
    log_success "Redis deployed"
    log_info "Redis hot cache configured with 15 min TTL for 10 base metrics"
}

deploy_clickhouse() {
    log_header "Deploying ClickHouse"
    
    # First ensure operator is installed
    log_info "Installing ClickHouse operator..."
    helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set artemis.enabled=true \
        --set clickhouse.enabled=true \
        --set zookeeper.enabled=true \
        --set nifikop.enabled=false \
        --set redis.enabled=true \
        --set dagster.enabled=false \
        --set prometheus.enabled=false \
        --set grafana.enabled=false \
        --wait \
        --timeout="$TIMEOUT"
    
    log_info "Waiting for ClickHouse operator..."
    sleep 20
    
    # Apply ClickHouse cluster CRD
    if [ -f "$CRDS_DIR/clickhouse-cluster.yaml" ]; then
        log_info "Creating ClickHouse cluster..."
        kubectl apply -f "$CRDS_DIR/clickhouse-cluster.yaml"
        
        log_info "Waiting for ClickHouse pods..."
        sleep 10
        wait_for_pods "clickhouse" "clickhouse.altinity.com/chi=telemetry-db" 300
        
        # Initialize schema
        if [ -f "$PROJECT_ROOT/charts/producer/templates/clickhouse-init-job.yaml" ]; then
            log_info "Running ClickHouse schema initialization..."
            kubectl apply -f "$PROJECT_ROOT/charts/producer/templates/clickhouse-init-job.yaml"
            sleep 30
        fi
    fi
    
    log_success "ClickHouse deployed with optimized schema"
}

deploy_nifi() {
    log_header "Deploying Apache NiFi"
    
    # Install NiFiKop operator
    log_info "Installing NiFiKop operator..."
    helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set artemis.enabled=true \
        --set clickhouse.enabled=true \
        --set zookeeper.enabled=true \
        --set nifikop.enabled=true \
        --set redis.enabled=true \
        --set dagster.enabled=false \
        --set prometheus.enabled=false \
        --set grafana.enabled=false \
        --wait \
        --timeout="$TIMEOUT"
    
    log_info "Waiting for NiFiKop operator..."
    sleep 30
    
    # Apply NiFi cluster CRD
    if [ -f "$CRDS_DIR/nifi-cluster.yaml" ]; then
        log_info "Creating NiFi cluster..."
        kubectl apply -f "$CRDS_DIR/nifi-cluster.yaml"
        
        log_info "Waiting for NiFi pods (this may take several minutes)..."
        sleep 30
        wait_for_pods "nifi" "app=nifi" 600
    fi
    
    log_success "NiFi deployed"
    log_info "NiFi configured with ClickHouse JDBC driver and Redis NAR"
}

deploy_dagster() {
    log_header "Deploying Dagster"
    
    log_info "Installing Dagster orchestration platform..."
    helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set artemis.enabled=true \
        --set clickhouse.enabled=true \
        --set zookeeper.enabled=true \
        --set nifikop.enabled=true \
        --set redis.enabled=true \
        --set dagster.enabled=true \
        --set prometheus.enabled=false \
        --set grafana.enabled=false \
        --wait \
        --timeout="$TIMEOUT"
    
    wait_for_pods "$NAMESPACE" "app.kubernetes.io/name=dagster" 300
    
    log_success "Dagster deployed"
    log_info "Dagster jobs: redis_sync, hourly_aggregation, daily_aggregation, clickhouse_maintenance, data_quality"
    log_info "Dagster sensors: high_volume_sensor, data_freshness_sensor"
}

deploy_prometheus() {
    log_header "Deploying Prometheus"
    
    log_info "Installing Prometheus metrics collection..."
    helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set artemis.enabled=true \
        --set clickhouse.enabled=true \
        --set zookeeper.enabled=true \
        --set nifikop.enabled=true \
        --set redis.enabled=true \
        --set dagster.enabled=true \
        --set prometheus.enabled=true \
        --set grafana.enabled=false \
        --wait \
        --timeout="$TIMEOUT"
    
    wait_for_pods "$NAMESPACE" "app.kubernetes.io/name=prometheus" 180
    
    log_success "Prometheus deployed"
    log_info "Scrape targets: ClickHouse, NiFi, Redis, Dagster"
}

deploy_grafana() {
    log_header "Deploying Grafana"
    
    log_info "Installing Grafana dashboards..."
    helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set artemis.enabled=true \
        --set clickhouse.enabled=true \
        --set zookeeper.enabled=true \
        --set nifikop.enabled=true \
        --set redis.enabled=true \
        --set dagster.enabled=true \
        --set prometheus.enabled=true \
        --set grafana.enabled=true \
        --wait \
        --timeout="$TIMEOUT"
    
    wait_for_pods "$NAMESPACE" "app.kubernetes.io/name=grafana" 180
    
    # Apply Grafana dashboard ConfigMaps
    if [ -f "$CRDS_DIR/grafana-dashboards.yaml" ]; then
        log_info "Applying Grafana dashboard ConfigMaps..."
        kubectl apply -f "$CRDS_DIR/grafana-dashboards.yaml" -n "$NAMESPACE"
    fi
    
    log_success "Grafana deployed"
    log_info "Dashboards: Edge Analytics Overview, ClickHouse Metrics, Pipeline Health, Device Analytics, Data Quality"
    log_info "Datasources: Prometheus, ClickHouse, Redis"
}

deploy_dashboard_api() {
    log_header "Deploying Dashboard API"
    
    if [ -f "$CRDS_DIR/dashboard-api.yaml" ]; then
        log_info "Applying Dashboard API deployment..."
        kubectl apply -f "$CRDS_DIR/dashboard-api.yaml" -n "$NAMESPACE"
        
        wait_for_pods "$NAMESPACE" "app=dashboard-api" 120
        
        log_success "Dashboard API deployed"
        log_info "Redis endpoints: /api/dashboard/redis-metrics (3 hot metrics)"
        log_info "ClickHouse endpoints: /api/dashboard/clickhouse/temperature-timeseries, /hourly-stats, /device-stats"
    else
        log_warn "Dashboard API manifest not found, skipping"
    fi
}

deploy_flutter_dashboard() {
    log_header "Building Flutter Dashboard"
    
    FLUTTER_DIR="$PROJECT_ROOT/apps/flutter-dashboard"
    
    if [ -d "$FLUTTER_DIR" ]; then
        if command -v flutter &> /dev/null; then
            log_info "Building Flutter web app..."
            cd "$FLUTTER_DIR"
            flutter pub get
            flutter build web --release
            cd "$PROJECT_ROOT"
            
            log_success "Flutter dashboard built"
            log_info "Output: $FLUTTER_DIR/build/web/"
            log_info "Metrics: 3 from Redis (hot cache), 2 from ClickHouse (historical)"
        else
            log_warn "Flutter SDK not found, skipping build"
            log_info "Install Flutter: https://flutter.dev/docs/get-started/install"
            log_info "Then run: cd $FLUTTER_DIR && flutter build web"
        fi
    else
        log_warn "Flutter dashboard not found at $FLUTTER_DIR"
    fi
}

deploy_helm_chart() {
    log_header "Installing Full Edge Analytics Helm Chart"
    
    log_info "Installing/upgrading all components..."
    helm upgrade --install "$RELEASE_NAME" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --wait \
        --timeout="$TIMEOUT" \
        --set artemis.enabled=true \
        --set clickhouse.enabled=true \
        --set zookeeper.enabled=true \
        --set nifikop.enabled=true \
        --set redis.enabled=true \
        --set dagster.enabled=true \
        --set prometheus.enabled=true \
        --set grafana.enabled=true
    
    log_info "Waiting for operators to initialize..."
    sleep 30
    
    log_success "Helm chart installed"
}

deploy_producer() {
    log_header "Deploying IoT Producer"
    
    PRODUCER_CHART="$PROJECT_ROOT/charts/producer"
    
    if [ -d "$PRODUCER_CHART" ]; then
        log_info "Installing producer chart..."
        helm upgrade --install producer "$PRODUCER_CHART" \
            --namespace "$NAMESPACE" \
            --set devices.count=50 \
            --set simulation.duration=3600 \
            --set redis.enabled=true \
            --wait \
            --timeout=5m
        
        log_success "Producer deployed"
    else
        log_warn "Producer chart not found, skipping"
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

deploy_all() {
    log_header "Full Deployment - All Components"
    
    for component in "${COMPONENTS[@]}"; do
        deploy_component "$component"
    done
    
    show_summary
}

deploy_component() {
    local component=$1
    
    case $component in
        terraform)       deploy_terraform ;;
        namespace)       deploy_namespace ;;
        cert-manager)    deploy_cert_manager ;;
        helm-deps)       deploy_helm_deps ;;
        zookeeper)       deploy_zookeeper ;;
        artemis)         deploy_artemis ;;
        redis)           deploy_redis ;;
        clickhouse)      deploy_clickhouse ;;
        nifi)            deploy_nifi ;;
        dagster)         deploy_dagster ;;
        prometheus)      deploy_prometheus ;;
        grafana)         deploy_grafana ;;
        dashboard-api)   deploy_dashboard_api ;;
        producer)        deploy_producer ;;
        flutter-dashboard) deploy_flutter_dashboard ;;
        helm-chart)      deploy_helm_chart ;;  # Deploy all at once
        *)
            log_error "Unknown component: $component"
            show_usage
            exit 1
            ;;
    esac
}

show_summary() {
    echo ""
    log_header "Deployment Complete!"
    
    echo ""
    echo -e "${GREEN}Components deployed:${NC}"
    echo "  • GKE Cluster (Terraform - Spot VMs, nip.io)"
    echo "  • Namespace: $NAMESPACE"
    echo "  • cert-manager + Let's Encrypt"
    echo "  • NGINX Ingress Controller"
    echo "  • Artemis MQTT Broker"
    echo "  • ClickHouse Operator + Cluster"
    echo "  • NiFi Operator + Cluster"
    echo "  • Redis Cache (15 min TTL hot metrics)"
    echo "  • Dagster Orchestration (5 jobs, 2 sensors)"
    echo "  • Prometheus Metrics"
    echo "  • Grafana Dashboards (5 dashboards incl. ClickHouse)"
    echo "  • Dashboard API (Redis + ClickHouse endpoints)"
    echo "  • IoT Producer (10-100 devices, 10 metrics)"
    echo "  • Flutter Dashboard (optional - requires Flutter SDK)"
    echo ""
    
    # Show nip.io URLs if terraform was used
    if [ -d "$TERRAFORM_DIR" ] && [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        echo -e "${CYAN}Service URLs (nip.io):${NC}"
        cd "$TERRAFORM_DIR"
        terraform output service_urls 2>/dev/null || true
        cd "$PROJECT_ROOT"
        echo ""
    fi
    
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Configure NiFi flow: ./scripts/access-info.sh"
    echo "  2. View Grafana dashboards"
    echo "  3. Check Dagster jobs"
    echo ""
    echo -e "${CYAN}Access info:${NC} ./scripts/access-info.sh"
}

show_status() {
    log_header "Deployment Status"
    
    echo ""
    echo -e "${BLUE}Namespaces:${NC}"
    kubectl get namespaces | grep -E "^(edge|clickhouse|nifi|cert-manager)" || echo "  None found"
    
    echo ""
    echo -e "${BLUE}Pods in 'edge' namespace:${NC}"
    kubectl get pods -n edge --no-headers 2>/dev/null || echo "  None found"
    
    echo ""
    echo -e "${BLUE}Pods in 'clickhouse' namespace:${NC}"
    kubectl get pods -n clickhouse --no-headers 2>/dev/null || echo "  None found"
    
    echo ""
    echo -e "${BLUE}Pods in 'nifi' namespace:${NC}"
    kubectl get pods -n nifi --no-headers 2>/dev/null || echo "  None found"
    
    echo ""
    echo -e "${BLUE}Helm Releases:${NC}"
    helm list -A | grep -E "(edge-analytics|producer)" || echo "  None found"
}

destroy_all() {
    log_header "Destroying All Components"
    
    log_warn "This will delete all Edge Analytics resources!"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted"
        exit 0
    fi
    
    log_info "Deleting producer..."
    helm uninstall producer -n "$NAMESPACE" 2>/dev/null || true
    
    log_info "Deleting CRDs..."
    kubectl delete -f "$CRDS_DIR/" --ignore-not-found 2>/dev/null || true
    
    log_info "Deleting Helm release..."
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null || true
    
    log_info "Deleting namespaces..."
    kubectl delete namespace "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    kubectl delete namespace clickhouse --ignore-not-found 2>/dev/null || true
    kubectl delete namespace nifi --ignore-not-found 2>/dev/null || true
    
    log_success "All components destroyed"
}

show_usage() {
    echo ""
    echo -e "${CYAN}Edge Analytics Deployment Script${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 [command] [component]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  all          Deploy all components in order (default)"
    echo "  deploy       Deploy a specific component"
    echo "  status       Show deployment status"
    echo "  destroy      Destroy all components"
    echo "  help         Show this help message"
    echo ""
    echo -e "${YELLOW}Components (in deployment order):${NC}"
    echo "  terraform           Provision GKE cluster (Spot VMs, nip.io, cert-manager)"
    echo "  namespace           Create required namespaces"
    echo "  cert-manager        Install cert-manager (skip if using terraform)"
    echo "  helm-deps           Update Helm dependencies"
    echo "  zookeeper           Deploy Zookeeper (NiFi coordination)"
    echo "  artemis             Deploy Artemis MQTT broker"
    echo "  redis               Deploy Redis cache (hot metrics, 15 min TTL)"
    echo "  clickhouse          Deploy ClickHouse operator + cluster"
    echo "  nifi                Deploy NiFi operator + cluster"
    echo "  dagster             Deploy Dagster orchestration"
    echo "  prometheus          Deploy Prometheus metrics"
    echo "  grafana             Deploy Grafana dashboards (5 dashboards)"
    echo "  dashboard-api       Deploy Dashboard API (Redis + ClickHouse)"
    echo "  producer            Deploy IoT device simulator (10-100 devices)"
    echo "  flutter-dashboard   Build Flutter dashboard app (requires Flutter SDK)"
    echo ""
    echo -e "${YELLOW}Special:${NC}"
    echo "  helm-chart          Deploy ALL K8s components at once via Helm"
    echo ""
    echo -e "${YELLOW}GKE Cluster (Terraform):${NC}"
    echo "  Project:    data-cluster-gke1"
    echo "  Zone:       us-central1-a (zonal - cheapest)"
    echo "  Nodes:      Spot VMs e2-medium (~\$7/month each)"
    echo "  Ingress:    NGINX + nip.io wildcard DNS"
    echo "  TLS:        cert-manager + Let's Encrypt"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 deploy terraform          # Create GKE cluster first"
    echo "  $0                           # Deploy all in chain"
    echo "  $0 all                       # Deploy all in chain"
    echo "  $0 deploy redis              # Deploy only Redis"
    echo "  $0 deploy helm-chart         # Deploy all K8s components at once"
    echo "  $0 status                    # Show status"
    echo "  $0 destroy                   # Destroy everything"
    echo ""
    echo -e "${YELLOW}Full deployment (new cluster):${NC}"
    echo "  $0 deploy terraform"
    echo "  $0 deploy helm-deps"
    echo "  $0 deploy zookeeper"
    echo "  $0 deploy artemis"
    echo "  $0 deploy redis"
    echo "  $0 deploy clickhouse"
    echo "  $0 deploy nifi"
    echo "  $0 deploy dagster"
    echo "  $0 deploy prometheus"
    echo "  $0 deploy grafana"
    echo "  $0 deploy dashboard-api"
    echo "  $0 deploy producer"
    echo "  $0 deploy flutter-dashboard  # Optional"
    echo ""
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    # Check dependencies
    check_dependency kubectl
    check_dependency helm
    
    local command=${1:-all}
    local component=${2:-}
    
    case $command in
        all)
            deploy_all
            ;;
        deploy)
            if [ -z "$component" ]; then
                log_error "Component name required"
                show_usage
                exit 1
            fi
            deploy_component "$component"
            ;;
        status)
            show_status
            ;;
        destroy)
            destroy_all
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            # Assume it's a component name for backward compatibility
            if [[ " ${COMPONENTS[*]} " =~ " ${command} " ]]; then
                deploy_component "$command"
            else
                log_error "Unknown command: $command"
                show_usage
                exit 1
            fi
            ;;
    esac
}

main "$@"


