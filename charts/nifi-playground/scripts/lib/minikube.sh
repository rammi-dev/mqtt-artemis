#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

check_minikube_running() {
    if ! minikube status -p nifi-playground > /dev/null 2>&1; then
        log_error "Minikube is not running. Please run ./scripts/setup-minikube.sh first."
        exit 1
    fi
}

start_minikube() {
    local profile=$1
    local cpus=$2
    local memory=$3
    local nodes=$4

    log_info "Starting Minikube cluster '$profile'..."
    log_info "Configuration: $cpus CPUs, $memory MB RAM, $nodes Nodes"

    minikube start \
      --profile "$profile" \
      --cpus "$cpus" \
      --memory "$memory" \
      --nodes "$nodes" \
      --addons=ingress,metrics-server,dashboard

    log_info "Minikube cluster '$profile' started successfully."
    echo "Use 'minikube profile $profile' to switch to this cluster context if needed."
}
