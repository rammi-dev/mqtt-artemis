#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

create_secrets() {
    log_info "Creating Secrets from .env..."
    if [ ! -f .env ]; then
        log_error ".env file not found. Please create one from .env.example"
        exit 1
    fi
    
    # Export variables from .env
    set -a
    source .env
    set +a
    
    # Create namespace if it doesn't exist (secrets are namespaced)
    kubectl create namespace postgres --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace nifi-registry --dry-run=client -o yaml | kubectl apply -f -

    # Create Secret for Postgres (used by Postgres Chart)
    kubectl create secret generic postgres-auth \
        --namespace postgres \
        --from-literal=postgres-password="$POSTGRES_PASSWORD" \
        --from-literal=postgres-user="$POSTGRES_USER" \
        --from-literal=postgres-database="$POSTGRES_DB" \
        --dry-run=client -o yaml | kubectl apply -f -

    # Create Secret for Registry (used by Registry Chart to connect to DB)
    kubectl create secret generic nifi-registry-db-auth \
        --namespace nifi-registry \
        --from-literal=NIFI_REGISTRY_DB_PASSWORD="$POSTGRES_PASSWORD" \
        --from-literal=NIFI_REGISTRY_DB_USERNAME="$POSTGRES_USER" \
        --dry-run=client -o yaml | kubectl apply -f -
}

deploy_storage() {
    log_info "Deploying StorageClass..."
    kubectl apply -f storage/storage-class.yaml
    if [ -f storage/minikube-storage-fix.yaml ]; then
        kubectl apply -f storage/minikube-storage-fix.yaml
    fi
}

deploy_zookeeper() {
    log_info "Deploying Shared ZooKeeper..."
    helm dependency update helm/zookeeper
    helm upgrade --install zookeeper helm/zookeeper \
      --namespace zk \
      --create-namespace \
      --wait \
      -f helm/zookeeper/values-playground.yaml
}

deploy_postgres() {
    log_info "Deploying Shared PostgreSQL..."
    helm dependency update helm/postgres
    helm upgrade --install postgres helm/postgres \
      --namespace postgres \
      --create-namespace \
      --wait \
      -f helm/postgres/values-playground.yaml
}

deploy_operator() {
    log_info "Deploying NiFi Operator..."
    # Create namespaces if they don't exist
    kubectl create namespace nifi-operator --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace nifi-initcluster --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace nifi-secondary --dry-run=client -o yaml | kubectl apply -f -

    helm dependency update helm/nifi-operator
    helm upgrade --install nifi-operator helm/nifi-operator \
      --namespace nifi-operator \
      --create-namespace \
      --wait \
      -f helm/nifi-operator/values-playground.yaml
}

deploy_registry() {
    log_info "Deploying NiFi Registry..."
    
    helm dependency update helm/nifi-registry
    
    helm upgrade --install nifi-registry helm/nifi-registry \
      --namespace nifi-registry \
      --create-namespace \
      --wait \
      -f helm/nifi-registry/values-playground.yaml
      
    log_info "Waiting for NiFi Registry to be ready..."
    kubectl wait --for=condition=ready pod/nifi-registry-0 -n nifi-registry --timeout=300s

    echo ""
    echo "================================================================"
    echo "NiFi Registry Deployed Successfully!"
    echo "Access URL: http://localhost:8080/nifi-registry"
    echo "Note: You may need to forward the port if not using an Ingress:"
    echo "      kubectl port-forward -n nifi-registry svc/nifi-registry 8080:18080"
    echo "================================================================"
    echo ""
}

build_images() {
    log_info "Building Custom Images..."
    
    # Registry Image
    log_info "Building NiFi Registry Custom Image (nifi-registry-custom:0.1.0)..."
    if minikube -p nifi-playground image build -t nifi-registry-custom:0.1.0 images/nifi-registry/; then
        log_info "Registry Image built successfully."
    else
        log_error "Failed to build Registry image. Exiting."
        exit 1
    fi
}

deploy_clusters() {
    log_info "Deploying NiFi Cluster (Init)..."
    helm dependency update helm/nifi-cluster
    helm upgrade --install nifi-cluster-init helm/nifi-cluster \
      --namespace nifi-initcluster \
      --create-namespace \
      -f helm/nifi-cluster/values-playground.yaml

    log_info "Deploying NiFi Cluster (Secondary)..."
    helm upgrade --install nifi-cluster-secondary helm/nifi-cluster \
      --namespace nifi-secondary \
      --create-namespace \
      -f helm/nifi-cluster/values-playground.yaml
}

show_deployment_order() {
    echo -e "${GREEN}Deployment Execution Order:${NC}"
    echo "1. Storage Provisioning"
    echo "   └── StorageClass (storage-zookeeper)"
    echo "2. Build Custom Images"
    echo "   └── NiFi Registry (PostgreSQL Driver)"
    echo "3. Secrets Generation (Credentials)"
    echo "   └── from .env to Kubernetes Secrets"
    echo "4. Shared Infrastructure"
    echo "   ├── ZooKeeper (Shared Coordination)"
    echo "   └── PostgreSQL (Shared Database)"
    echo "4. NiFi Operator (CRD & Controller)"
    echo "5. NiFi Registry (Flow Versioning)"
    echo "   └── connects to PostgreSQL"
    echo "6. NiFi Clusters"
    echo "   ├── Init Cluster"
    echo "   │   └── connects to ZooKeeper, Registry"
    echo "   └── Secondary Cluster"
    echo "       └── connects to ZooKeeper, Registry"
}
