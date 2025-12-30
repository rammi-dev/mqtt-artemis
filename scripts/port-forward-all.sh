#!/bin/bash
# =============================================================================
# Port Forward All Services
# =============================================================================
# Start port forwards for all services in the edge namespace
#
# Usage:
#   ./scripts/port-forward-all.sh        # Start all port forwards
#   ./scripts/port-forward-all.sh stop   # Stop all port forwards
#   ./scripts/port-forward-all.sh status # Check status of port forwards
# =============================================================================

set -e

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Check required tools
check_required_tools kubectl

# Check kubectl context
check_kubectl_context

NAMESPACE="edge"
PID_DIR="/tmp/k8s-port-forwards"

# Service configurations: name:local_port:service:remote_port
SERVICES=(
    "nifi:8080:edge-nifi:8080"
    "grafana:3000:edge-analytics-grafana:80"
    "dagster:3001:edge-analytics-dagster-webserver:80"
    "dashboard:8000:dashboard-api:8000"
    "clickhouse:8123:clickhouse-telemetry-db:8123"
    "redis:6379:edge-analytics-redis-master:6379"
    "prometheus:9090:edge-analytics-prometheus-server:80"
    "keycloak:8180:keycloak-operator-service:80"
    "minio-console:9001:minio-console:9001"
    "minio-api:9000:minio:9000"
)

# Create PID directory
mkdir -p "$PID_DIR"

start_port_forward() {
    local name=$1
    local local_port=$2
    local service=$3
    local remote_port=$4
    local pid_file="$PID_DIR/$name.pid"

    # Check if already running
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_warn "$name: Already running (PID: $pid) on port $local_port"
            return 0
        fi
        rm -f "$pid_file"
    fi

    # Check if service exists
    if ! kubectl get svc "$service" -n "$NAMESPACE" &>/dev/null; then
        log_warn "$name: Service $service not found, skipping"
        return 0
    fi

    # Start port forward
    kubectl port-forward -n "$NAMESPACE" "svc/$service" "$local_port:$remote_port" &>/dev/null &
    local pid=$!
    echo "$pid" > "$pid_file"
    
    # Brief wait to check if it started successfully
    sleep 0.5
    if kill -0 "$pid" 2>/dev/null; then
        log_info "$name: Started on localhost:$local_port (PID: $pid)"
    else
        log_error "$name: Failed to start"
        rm -f "$pid_file"
        return 1
    fi
}

stop_port_forward() {
    local name=$1
    local pid_file="$PID_DIR/$name.pid"

    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            log_info "$name: Stopped (PID: $pid)"
        fi
        rm -f "$pid_file"
    fi
}

check_status() {
    local name=$1
    local local_port=$2
    local pid_file="$PID_DIR/$name.pid"

    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  \033[32m●\033[0m $name: Running on localhost:$local_port (PID: $pid)"
            return 0
        fi
    fi
    echo -e "  \033[31m○\033[0m $name: Not running (port $local_port)"
    return 1
}

start_all() {
    print_header "Starting Port Forwards"
    
    for entry in "${SERVICES[@]}"; do
        IFS=':' read -r name local_port service remote_port <<< "$entry"
        start_port_forward "$name" "$local_port" "$service" "$remote_port"
    done
    
    echo ""
    print_section "Access URLs"
    echo "  NiFi:        http://localhost:8080/nifi"
    echo "  Grafana:     http://localhost:3000"
    echo "  Dagster:     http://localhost:3001"
    echo "  Dashboard:   http://localhost:8000"
    echo "  ClickHouse:  http://localhost:8123"
    echo "  Redis:       localhost:6379"
    echo "  Prometheus:  http://localhost:9090"
    echo "  Keycloak:    http://localhost:8180"
    echo "  MinIO UI:    http://localhost:9001"
    echo "  MinIO API:   http://localhost:9000"
    echo ""
    log_info "Use './scripts/port-forward-all.sh stop' to stop all port forwards"
}

stop_all() {
    print_header "Stopping Port Forwards"
    
    for entry in "${SERVICES[@]}"; do
        IFS=':' read -r name local_port service remote_port <<< "$entry"
        stop_port_forward "$name"
    done
    
    # Clean up any orphaned kubectl port-forward processes
    pkill -f "kubectl port-forward -n $NAMESPACE" 2>/dev/null || true
    
    log_info "All port forwards stopped"
}

status_all() {
    print_header "Port Forward Status"
    
    local running=0
    local stopped=0
    
    for entry in "${SERVICES[@]}"; do
        IFS=':' read -r name local_port service remote_port <<< "$entry"
        if check_status "$name" "$local_port"; then
            ((running++))
        else
            ((stopped++))
        fi
    done
    
    echo ""
    log_info "Running: $running, Stopped: $stopped"
}

# Main
case "${1:-start}" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    status)
        status_all
        ;;
    restart)
        stop_all
        echo ""
        start_all
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
