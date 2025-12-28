#!/bin/bash
# =============================================================================
# Script Library - Common Functions
# =============================================================================
# Shared functions for deployment scripts
#
# Usage:
#   source scripts/lib/common.sh
# =============================================================================

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
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

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required tools
check_required_tools() {
    local missing_tools=()

    for tool in "$@"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi
}

# Check if kubectl context is set
check_kubectl_context() {
    if ! kubectl cluster-info &>/dev/null; then
        log_error "kubectl is not configured or cluster is not accessible"
        log_info "Run: ./scripts/deploy-gke.sh kubeconfig"
        exit 1
    fi
}

# Check if namespace exists
check_namespace() {
    local namespace=$1
    if ! kubectl get namespace "$namespace" &>/dev/null; then
        log_warn "Namespace '$namespace' not found"
        return 1
    fi
    return 0
}

# Get Terraform output
get_terraform_output() {
    local output_name=$1
    local terraform_dir=${2:-terraform/gke}

    if [ ! -d "$terraform_dir" ]; then
        log_error "Terraform directory not found: $terraform_dir"
        exit 1
    fi

    cd "$terraform_dir"
    local value
    value=$(terraform output -raw "$output_name" 2>/dev/null)
    local exit_code=$?
    cd - >/dev/null

    if [ $exit_code -ne 0 ]; then
        log_error "Failed to get Terraform output: $output_name"
        log_info "Have you run 'terraform apply' yet?"
        exit 1
    fi

    echo "$value"
}

# Wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}

    log_info "Waiting for pods with label '$label' in namespace '$namespace'..."
    
    if kubectl wait --for=condition=ready pod -l "$label" \
        -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
        log_success "Pods are ready"
        return 0
    else
        log_warn "Timeout waiting for pods to be ready"
        return 1
    fi
}

# Check if Helm release exists
helm_release_exists() {
    local release=$1
    local namespace=$2

    helm list -n "$namespace" 2>/dev/null | grep -q "^$release"
}

# Get service URL
get_service_url() {
    local service=$1
    local namespace=$2
    local port=$3

    kubectl get svc "$service" -n "$namespace" \
        -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null
}

# Print section header
print_header() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
}

# Print section
print_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Confirm action
confirm_action() {
    local message=$1
    local default=${2:-no}

    if [ "$default" = "yes" ]; then
        read -p "$message (Y/n): " -r
        [[ $REPLY =~ ^[Nn]$ ]] && return 1
    else
        read -p "$message (y/N): " -r
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
    fi
    return 0
}
