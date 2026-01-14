#!/bin/bash
set -e

# Ensure we are in the project root
cd "$(dirname "$0")/.."

# Source libraries
source scripts/lib/deployment.sh
source scripts/lib/utils.sh
source scripts/lib/minikube.sh

usage() {
    echo "Usage: $0 [component]"
    echo "Components:"
    echo "  all       - Deploy everything (ZooKeeper, Postgres, Operator, Registry, Clusters)"
    echo "  order     - Show deployment execution order"
    echo "  build     - Build custom images (Registry)"
    echo "  secrets   - Generate Kubernetes secrets from .env"
    echo "  storage-zookeeper - Deploy StorageClass for Zookeeper"
    echo "  zookeeper - Deploy Shared ZooKeeper"
    echo "  postgres  - Deploy Shared PostgreSQL"
    echo "  operator  - Deploy NiFi Operator only"
    echo "  registry  - Deploy NiFi Registry only"
    echo "  clusters  - Deploy NiFi Clusters only (Init & Secondary)"
    exit 1
}

parse_args() {
    if [ $# -eq 0 ]; then
        usage
    fi
    COMPONENT=$1
}

# Main Execution
parse_args "$@"

# Check Minikube for deployment commands
if [[ "$COMPONENT" != "order" && "$COMPONENT" != "secrets" ]]; then
    check_minikube_running
fi

case "$COMPONENT" in
    all)
        show_deployment_order
        deploy_storage
        build_images
        create_secrets
        deploy_zookeeper
        deploy_postgres
        deploy_operator
        deploy_registry
        deploy_clusters
        ;;
    order)
        show_deployment_order
        ;;
    build)
        build_images
        ;;
    secrets)
        create_secrets
        ;;
    storage-zookeeper)
        deploy_storage
        ;;
    zookeeper)
        deploy_zookeeper
        ;;
    postgres)
        create_secrets
        deploy_postgres
        ;;
    operator)
        deploy_operator
        ;;
    registry)
        deploy_registry
        ;;
    clusters)
        deploy_clusters
        ;;
    *)
        usage
        ;;
esac

if [[ "$COMPONENT" != "order" && "$COMPONENT" != "secrets" ]]; then
    log_info "Deployment task '$COMPONENT' completed successfully!"
    echo "Use 'kubectl get pods -A' to check status."
fi
