#!/bin/bash
# Simplified deployment using umbrella chart

set -e

echo "========================================="
echo "Edge Analytics Deployment (Umbrella Chart)"
echo "========================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace edge --dry-run=client -o yaml | kubectl apply -f -

# Update Helm dependencies
echo -e "${YELLOW}Downloading Helm dependencies...${NC}"
cd charts/edge-analytics
helm dependency update
cd ../..

# Install cert-manager (required for NiFiKop)
echo -e "${YELLOW}Installing cert-manager...${NC}"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s || true

# Install umbrella chart (all dependencies)
echo -e "${YELLOW}Installing edge-analytics umbrella chart...${NC}"
helm upgrade --install edge-analytics charts/edge-analytics/ \
  --namespace edge \
  --wait --timeout=10m

# Wait for operators to be ready
echo -e "${YELLOW}Waiting for operators...${NC}"
sleep 30

# Apply CRDs (NiFi and ClickHouse clusters)
echo -e "${YELLOW}Creating NiFi and ClickHouse clusters...${NC}"
kubectl apply -f charts/edge-analytics/crds/ -n edge

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "All components deployed via Helm dependencies!"
echo "No template files to maintain in your repo!"
echo ""
echo -e "${YELLOW}To see access information (port-forward commands, credentials):${NC}"
echo "  ./scripts/access-info.sh"


