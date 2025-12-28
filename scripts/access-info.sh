#!/bin/bash
# =============================================================================
# Access Information Script
# =============================================================================
# Display access information for deployed services
#
# Usage:
#   ./scripts/access-info.sh
# =============================================================================

set -e

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Check required tools
check_required_tools kubectl

# Check kubectl context
check_kubectl_context

# Get Terraform outputs
INGRESS_IP=$(get_terraform_output "ingress_ip" 2>/dev/null || echo "N/A")
NIP_IO_DOMAIN=$(get_terraform_output "nip_io_domain" 2>/dev/null || echo "N/A")

print_header "Edge Analytics - Access Information"

# Check if edge namespace exists
if ! check_namespace "edge"; then
    log_warn "Edge namespace not found. Have you deployed yet?"
    log_info "Run: ./scripts/deploy-gke.sh all"
    exit 1
fi

# =============================================================================
# Infrastructure Services
# =============================================================================

print_section "Infrastructure"

echo "Ingress IP: $INGRESS_IP"
echo "Domain: $NIP_IO_DOMAIN"
echo ""

if [ "$INGRESS_IP" != "N/A" ]; then
    echo "Service URLs (via Ingress):"
    echo "  Grafana:    https://grafana.$NIP_IO_DOMAIN"
    echo "  NiFi:       https://nifi.$NIP_IO_DOMAIN"
    echo "  Dagster:    https://dagster.$NIP_IO_DOMAIN"
    echo "  Dashboard:  https://api.$NIP_IO_DOMAIN"
    echo ""
fi

# =============================================================================
# Port Forward Commands
# =============================================================================

print_section "Port Forward Commands"

echo "NiFi UI:"
echo "  kubectl port-forward -n edge svc/edge-nifi 8080:8080"
echo "  Access: http://localhost:8080/nifi"
echo ""

echo "Grafana:"
echo "  kubectl port-forward -n edge svc/edge-analytics-grafana 3000:80"
echo "  Access: http://localhost:3000"
echo "  Credentials: admin / admin-secret"
echo ""

echo "Dagster:"
echo "  kubectl port-forward -n edge svc/edge-analytics-dagster-webserver 3001:80"
echo "  Access: http://localhost:3001"
echo ""

echo "Dashboard API:"
echo "  kubectl port-forward -n edge svc/dashboard-api 8000:8000"
echo "  Access: http://localhost:8000"
echo "  Docs: http://localhost:8000/docs"
echo ""

echo "ClickHouse:"
echo "  kubectl port-forward -n edge svc/clickhouse-telemetry-db 8123:8123"
echo "  Access: http://localhost:8123"
echo "  Credentials: admin / password"
echo ""

echo "Redis:"
echo "  kubectl port-forward -n edge svc/edge-analytics-redis-master 6379:6379"
echo "  Access: localhost:6379"
echo "  Password: redis-secret"
echo ""

echo "Prometheus:"
echo "  kubectl port-forward -n edge svc/edge-analytics-prometheus-server 9090:80"
echo "  Access: http://localhost:9090"
echo ""

# =============================================================================
# Service Details
# =============================================================================

print_section "Service Details"

echo "Artemis MQTT:"
echo "  Internal: artemis-broker.edge.svc.cluster.local:1883"
echo "  Credentials: admin / admin"
echo ""

echo "ClickHouse:"
echo "  Internal: clickhouse-telemetry-db.edge.svc.cluster.local:8123"
echo "  Database: telemetry"
echo "  Table: events"
echo ""

echo "Redis:"
echo "  Internal: edge-analytics-redis-master.edge.svc.cluster.local:6379"
echo "  Password: redis-secret"
echo ""

# =============================================================================
# Quick Commands
# =============================================================================

print_section "Quick Commands"

echo "Check all pods:"
echo "  kubectl get pods -n edge"
echo ""

echo "Check services:"
echo "  kubectl get svc -n edge"
echo ""

echo "Check ingress:"
echo "  kubectl get ingress -A"
echo ""

echo "View logs:"
echo "  kubectl logs -n edge -l app=nifi"
echo "  kubectl logs -n edge -l app=clickhouse"
echo "  kubectl logs -n edge -l app=dashboard-api"
echo ""

echo "Deploy test producer:"
echo "  helm install producer charts/producer/ -n edge"
echo ""

# =============================================================================
# Dashboard API Endpoints
# =============================================================================

print_section "Dashboard API Endpoints"

echo "Health Check:"
echo "  curl http://localhost:8000/health"
echo ""

echo "Aggregated Data (from Dagster → Redis):"
echo "  System Health:  http://localhost:8000/api/dashboard/system-health"
echo "  Device Stats:   http://localhost:8000/api/dashboard/device-stats"
echo "  Timeseries:     http://localhost:8000/api/dashboard/timeseries"
echo "  All Data:       http://localhost:8000/api/dashboard/all"
echo ""

echo "Real-time Data (from NiFi → Redis):"
echo "  All Devices:    http://localhost:8000/api/realtime/devices"
echo "  Single Device:  http://localhost:8000/api/realtime/device/{device_id}"
echo "  Event Stream:   http://localhost:8000/api/realtime/stream"
echo "  RT Stats:       http://localhost:8000/api/realtime/stats"
echo ""

# =============================================================================
# Cluster Status
# =============================================================================

print_section "Cluster Status"

echo "Namespaces:"
kubectl get namespaces | grep -E "NAME|cert-manager|ingress-nginx|edge" || true
echo ""

echo "Pods in edge namespace:"
kubectl get pods -n edge --no-headers 2>/dev/null | awk '{print "  " $1 " - " $3}' || echo "  No pods found"
echo ""

print_header "Access Information Complete"

log_info "To access services, use the port-forward commands above"
log_info "Or access via ingress URLs if DNS is configured"