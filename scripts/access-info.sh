#!/bin/bash
# Display access information for deployed services

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Edge Analytics - Access Information${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Check if namespace exists
if ! kubectl get namespace edge &>/dev/null; then
    echo -e "${YELLOW}Warning: 'edge' namespace not found. Have you deployed yet?${NC}"
    echo "Run: ./deploy.sh"
    exit 1
fi

echo -e "${CYAN}=== NiFi UI ===${NC}"
echo "Port Forward Command:"
echo "  kubectl port-forward -n edge svc/edge-nifi 8080:8080"
echo ""
echo "Access:"
echo "  URL: http://localhost:8080/nifi"
echo "  Username: admin"
echo "  Password: (check NiFi pod logs)"
echo ""
echo "Get Password:"
echo "  kubectl logs -n edge \$(kubectl get pods -n edge -l nifi_cr=edge-nifi -o name | head -1) | grep -i password"
echo ""

echo -e "${CYAN}=== ClickHouse ===${NC}"
echo "Port Forward Command:"
echo "  kubectl port-forward -n edge svc/clickhouse-telemetry-db 8123:8123"
echo ""
echo "Access:"
echo "  HTTP: http://localhost:8123"
echo "  Username: admin"
echo "  Password: password"
echo ""
echo "Query Example:"
echo "  curl -u admin:password 'http://localhost:8123/?query=SELECT+count(*)+FROM+telemetry.events'"
echo ""
echo "Direct Query (no port-forward):"
echo "  kubectl exec -n edge clickhouse-telemetry-db-0-0-0 -- clickhouse-client -u admin --password=password --query='SELECT count(*) FROM telemetry.events'"
echo ""

echo -e "${CYAN}=== Artemis MQTT ===${NC}"
echo "Service:"
echo "  Internal: artemis-broker.edge.svc.cluster.local:1883"
echo ""
echo "Credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Test MQTT (from inside cluster):"
echo "  kubectl run mqtt-test --rm -it --image=eclipse-mosquitto:latest -- \\"
echo "    mosquitto_sub -h artemis-broker.edge.svc.cluster.local -t raw-telemetry -u admin -P admin"
echo ""

echo -e "${CYAN}=== Zookeeper ===${NC}"
echo "Service:"
echo "  Internal: zookeeper-0.zookeeper.edge.svc.cluster.local:2181"
echo ""

echo -e "${CYAN}=== Quick Commands ===${NC}"
echo "Check all pods:"
echo "  kubectl get pods -n edge"
echo ""
echo "Check custom resources:"
echo "  kubectl get nificlusters,clickhouseinstallations -n edge"
echo ""
echo "Deploy test producer:"
echo "  helm install producer charts/producer/ -n edge"
echo ""

echo -e "${GREEN}=========================================${NC}"
echo ""
