#!/bin/bash
# Cleanup and redeploy Keycloak

set -e

echo "=== Cleaning up Keycloak resources ==="

# Uninstall Helm releases
echo "Uninstalling Helm releases..."
helm uninstall keycloak -n keycloak 2>/dev/null || true
helm uninstall keycloak-db -n keycloak 2>/dev/null || true

# Delete CRDs
echo "Deleting CRDs..."
kubectl delete crd keycloaks.k8s.keycloak.org 2>/dev/null || true
kubectl delete crd keycloakrealmimports.k8s.keycloak.org 2>/dev/null || true

# Delete ClusterRole and ClusterRoleBinding
echo "Deleting RBAC..."
kubectl delete clusterrole keycloak-operator 2>/dev/null || true
kubectl delete clusterrolebinding keycloak-operator 2>/dev/null || true

# Remove finalizers and delete namespace
echo "Deleting namespace..."
kubectl get namespace keycloak -o json 2>/dev/null | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/keycloak/finalize" -f - 2>/dev/null || true
kubectl delete namespace keycloak 2>/dev/null || true

echo "Waiting for cleanup to complete..."
sleep 15

echo "=== Deploying Keycloak ==="

# Deploy database
echo "Deploying Keycloak Database..."
cd /home/rami/Work/artemis
./scripts/deploy-gke.sh keycloak-db

echo "Waiting for database to be ready..."
sleep 15

# Deploy Keycloak
echo "Deploying Keycloak..."
./scripts/deploy-gke.sh keycloak

echo "=== Deployment complete ==="
