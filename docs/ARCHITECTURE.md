# Edge Analytics K8s Environment

## Architecture

This edge analytics environment provides a complete data pipeline for collecting, processing, and storing telemetry data from IoT devices using an **umbrella chart** approach with operator-based management.

```
Source Devices → Artemis MQTT → NiFi → ClickHouse
                      ↓             ↓        ↓
                 ArkMQ Op.    NiFiKop Op.  CH Op.
```

### Components (All Operator-Managed)

#### 1. **ArkMQ Operator + Artemis MQTT Broker**
- **Purpose**: Official operator managing Apache ActiveMQ Artemis message broker
- **Protocol**: MQTT (port 1883)
- **Deployment**: Helm dependency (ArkMQ operator v2.1.0)
- **Management**: CRD-based (ActiveMQArtemis custom resource)
- **License**: Apache 2.0 (open source)

#### 2. **NiFiKop Operator + Apache NiFi**
- **Purpose**: Operator managing NiFi for data ingestion and processing
- **Deployment**: Helm dependency (NiFiKop v1.9.0)
- **Features**:
  - Dataflow lifecycle management via CRDs
  - Graceful scaling and rolling upgrades
  - ClickHouse JDBC driver pre-installed
- **UI Access**: Port 8080
- **Dependencies**: Zookeeper (Bitnami chart)

#### 3. **ClickHouse Operator + ClickHouse Database**
- **Purpose**: Operator managing ClickHouse time-series database
- **Deployment**: Helm dependency (Altinity operator v0.23.0)
- **Schema**: 
  - Database: `telemetry`
  - Table: `events` (timestamp, device_id, temperature, pressure, status, msg_id)
- **Access**: HTTP interface on port 8123

#### 4. **Test Producer**
- **Purpose**: Generate test telemetry data
- **Deployment**: Standalone Helm chart
- **Output**: Publishes JSON messages to Artemis MQTT

## Deployment

### Prerequisites

- Kubernetes cluster (1.21+)
- Helm 3.x
- kubectl configured
- cert-manager (installed automatically by deployment script)

### Quick Start (Umbrella Chart)

```bash
# Deploy everything via umbrella chart
./scripts/deploy.sh
```

This script will:
1. Install cert-manager (for operators)
2. Download all Helm dependencies (ArkMQ, NiFiKop, ClickHouse operator, Zookeeper)
3. Deploy umbrella chart with all operators
4. Apply your custom CRDs (NiFi cluster, ClickHouse cluster)
5. Initialize ClickHouse schema

### Manual Deployment

```bash
# 1. Create namespace
kubectl create namespace edge

# 2. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 3. Download dependencies
cd charts/edge-analytics
helm dependency update
cd ../..

# 4. Install umbrella chart (all operators)
helm install edge-analytics charts/edge-analytics/ \
  --namespace edge \
  --create-namespace \
  --wait --timeout=10m

# 5. Apply CRDs (your custom configs)
kubectl apply -f charts/edge-analytics/crds/ -n edge

# 6. Initialize ClickHouse schema
kubectl apply -f manifests/clickhouse-schema.yaml -n edge

# 7. Deploy test producer (optional)
helm install producer charts/producer/ -n edge
```

## Chart Structure

### Umbrella Chart (charts/edge-analytics/)

```
edge-analytics/
├── Chart.yaml          # Dependencies only (no templates!)
├── values.yaml         # Configuration for all dependencies
├── README.md
├── ARTEMIS_OPTIONS.md
└── crds/               # Only 2 files you maintain
    ├── nifi-cluster.yaml       # Your NiFi configuration
    └── clickhouse-cluster.yaml # Your ClickHouse configuration
```

**Dependencies in Chart.yaml:**
- `arkmq-org-broker-operator` - Artemis operator
- `clickhouse-operator` - ClickHouse operator
- `zookeeper` - From Bitnami (for NiFi)
- `nifikop` - NiFi operator

### What You Maintain

**Only 2 CRD files:**
1. `charts/edge-analytics/crds/nifi-cluster.yaml` - NiFi cluster spec
2. `charts/edge-analytics/crds/clickhouse-cluster.yaml` - ClickHouse cluster spec

**Everything else is Helm dependencies** - downloaded automatically, no template maintenance!

## Configuration

### NiFi Data Flow

After deployment, configure the NiFi flow via the UI:

1. **Access NiFi UI**:
   ```bash
   kubectl port-forward -n edge svc/edge-nifi 8080:8080
   ```
   Open: http://localhost:8080/nifi

2. **Create Flow** (see `manifests/nifi-flow-config.yaml` for details):
   - **ConsumeMQTT**: Subscribe to `raw-telemetry` topic from Artemis
   - **EvaluateJsonPath**: Extract telemetry fields
   - **PutDatabaseRecord**: Insert into ClickHouse

3. **Configure ClickHouse Connection**:
   - URL: `jdbc:clickhouse://clickhouse-telemetry-db.clickhouse.svc.cluster.local:8123/telemetry`
   - Driver: Pre-installed ClickHouse JDBC driver
   - User: `admin` / Password: `password`

## Verification

### Check Deployments

```bash
# Check all pods
kubectl get pods -n edge

# Check operators
kubectl get pods -n edge | grep operator

# Check custom resources
kubectl get nificlusters -n edge
kubectl get clickhouseinstallations -n edge
kubectl get activemqartemis -n edge  # If using ArkMQ
```

## Upgrading

### Upgrade Dependencies

```bash
# Update dependency versions in Chart.yaml
vim charts/edge-analytics/Chart.yaml

# Update dependencies
helm dependency update charts/edge-analytics/

# Upgrade deployment
helm upgrade edge-analytics charts/edge-analytics/ -n edge
```

### Modify Your Configurations

```bash
# Edit your CRDs
vim charts/edge-analytics/crds/nifi-cluster.yaml
vim charts/edge-analytics/crds/clickhouse-cluster.yaml

# Apply changes
kubectl apply -f charts/edge-analytics/crds/ -n edge
```

## Benefits of This Architecture

### 1. **Minimal Maintenance**
- Only 2 CRD files to maintain
- All infrastructure managed by upstream Helm charts
- No template files in your repo

### 2. **Operator-Based**
- Consistent CRD pattern across all components
- Automatic reconciliation and healing
- Advanced lifecycle management

### 3. **Easy Upgrades**
- Bump dependency versions in Chart.yaml
- Run `helm dependency update`
- No manual template updates

## Troubleshooting

### Operators not starting

```bash
# Check cert-manager
kubectl get pods -n cert-manager

# Check operator logs
kubectl logs -n edge -l app.kubernetes.io/name=nifikop
kubectl logs -n edge -l app.kubernetes.io/name=clickhouse-operator
```

### NiFi cluster not creating

```bash
# Check NiFiCluster status
kubectl describe nificluster edge-nifi -n edge

# Check NiFiKop operator logs
kubectl logs -n edge -l app.kubernetes.io/name=nifikop
```

### ClickHouse connection issues

```bash
# Check ClickHouse pods
kubectl get pods -n edge -l clickhouse.altinity.com/chi=telemetry-db

# Test connection
kubectl exec -n edge clickhouse-telemetry-db-0-0-0 -- \
  clickhouse-client --query="SELECT 1"
```

## Cleanup

```bash
# Uninstall umbrella chart (removes all operators and resources)
helm uninstall edge-analytics -n edge

# Delete namespace
kubectl delete namespace edge

# Uninstall cert-manager (if not used by other apps)
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

## References

- [ArkMQ Broker Operator](https://arkmq.org/)
- [Apache NiFi Documentation](https://nifi.apache.org/docs.html)
- [NiFiKop Operator](https://konpyutaika.github.io/nifikop/)
- [ClickHouse Documentation](https://clickhouse.com/docs)
- [Altinity ClickHouse Operator](https://github.com/Altinity/clickhouse-operator)


```
Source Devices → Artemis MQTT → NiFi → ClickHouse
                                  ↓
                          (Data Processing)
```

### Components

#### 1. **Artemis MQTT Broker**
- **Purpose**: Message broker for collecting telemetry data from source devices
- **Protocol**: MQTT (port 1883)
- **Deployment**: Helm chart (`charts/artemis/`)
- **Configuration**: 
  - Single replica for edge deployment
  - Username: `admin` / Password: `admin`

#### 2. **Apache NiFi** (via NiFiKop Operator)
- **Purpose**: Data ingestion and processing
- **Deployment**: Helm chart (`charts/nifi-infra/`)
- **Features**:
  - Managed by NiFiKop Kubernetes operator
  - Dataflow lifecycle management via CRDs
  - Graceful scaling and rolling upgrades
  - ClickHouse JDBC driver pre-installed
- **UI Access**: Port 8080
- **Dependencies**: Zookeeper (deployed automatically)

#### 3. **ClickHouse**
- **Purpose**: Time-series database for telemetry storage
- **Deployment**: Helm chart (`charts/clickhouse-infra/`)
- **Schema**: 
  - Database: `telemetry`
  - Table: `events` (timestamp, device_id, temperature, pressure, status, msg_id)
- **Access**: HTTP interface on port 8123

#### 4. **Test Producer**
- **Purpose**: Generate test telemetry data
- **Deployment**: Helm chart (`charts/producer/`)
- **Output**: Publishes JSON messages to Artemis MQTT

## Deployment

### Prerequisites

- Kubernetes cluster (1.21+)
- Helm 3.x
- kubectl configured

### Quick Start

```bash
# Deploy all components
./deploy-edge-analytics.sh
```

This script will:
1. Install cert-manager (for NiFiKop)
2. Install NiFiKop operator
3. Deploy ClickHouse database
4. Deploy Artemis MQTT broker
5. Deploy NiFi with Zookeeper

### Manual Deployment

```bash
# 1. Create namespaces
kubectl create namespace clickhouse
kubectl create namespace nifi

# 2. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 3. Install NiFiKop operator
helm repo add konpyutaika https://konpyutaika.github.io/helm-charts
helm install nifikop konpyutaika/nifikop --namespace=nifi --set namespaces={"nifi"}

# 4. Deploy ClickHouse
helm install clickhouse charts/clickhouse-infra/ --namespace=clickhouse

# 5. Initialize ClickHouse schema
kubectl apply -f manifests/clickhouse-schema.yaml

# 6. Deploy Artemis
helm install artemis-activemq charts/artemis/

# 7. Deploy NiFi
helm install nifi charts/nifi-infra/ --namespace=nifi

# 8. Deploy test producer (optional)
helm install producer charts/producer/
```

## Configuration

### NiFi Data Flow

After deployment, configure the NiFi flow via the UI:

1. **Access NiFi UI**:
   ```bash
   kubectl port-forward -n nifi svc/edge-nifi 8080:8080
   ```
   Open: http://localhost:8080/nifi

2. **Create Flow** (see `manifests/nifi-flow-config.yaml` for details):
   - **ConsumeMQTT**: Subscribe to `raw-telemetry` topic from Artemis
   - **EvaluateJsonPath**: Extract telemetry fields
   - **PutDatabaseRecord**: Insert into ClickHouse

3. **Configure ClickHouse Connection**:
   - URL: `jdbc:clickhouse://clickhouse-telemetry-db.clickhouse.svc.cluster.local:8123/telemetry`
   - Driver: Pre-installed ClickHouse JDBC driver
   - User: `admin` / Password: `password`

## Verification

### Check Deployments

```bash
# Check all pods
kubectl get pods -A | grep -E 'nifi|clickhouse|artemis'

# Check NiFi cluster status
kubectl get nificlusters -n nifi

# Check ClickHouse installation
kubectl get chi -n clickhouse
```

### Test Data Flow

```bash
# 1. Deploy test producer
helm install producer charts/producer/

# 2. Check NiFi is processing data
kubectl logs -n nifi -l nifi_cr=edge-nifi --tail=50

# 3. Query ClickHouse
kubectl exec -n clickhouse clickhouse-telemetry-db-0-0-0 -- \
  clickhouse-client -u admin --password=password \
  --query="SELECT count(*) FROM telemetry.events"
```

## Helm Charts

### charts/nifi-infra/
- **Version**: 1.0.0
- **App Version**: NiFi 2.0.0
- **Dependencies**: NiFiKop operator
- **Values**: See `charts/nifi-infra/values.yaml`

### charts/clickhouse-infra/
- **Version**: 1.0.0
- **App Version**: ClickHouse 24.3
- **Values**: See `charts/clickhouse-infra/values.yaml`

### charts/artemis/
- **Version**: 0.1.1
- **App Version**: ActiveMQ Artemis latest
- **Values**: See `charts/artemis/values.yaml`

### charts/producer/
- **Version**: 1.0.0
- **Purpose**: Test data generator

## Customization

### Modify Resource Limits

Edit `values.yaml` in respective charts:

```bash
# NiFi resources
helm upgrade nifi charts/nifi-infra/ \
  --set nifi.resources.limits.memory=4Gi \
  --namespace=nifi

# ClickHouse resources
helm upgrade clickhouse charts/clickhouse-infra/ \
  --set clickhouse.resources.limits.memory=2Gi \
  --namespace=clickhouse
```

### Scale Components

```bash
# Scale Artemis replicas
helm upgrade artemis-activemq charts/artemis/ --set replicas=2

# Scale NiFi nodes (via NiFiKop)
kubectl edit nificluster edge-nifi -n nifi
# Add more nodes to spec.nodes[]
```

## Troubleshooting

### NiFi not starting

```bash
# Check NiFiKop operator logs
kubectl logs -n nifi -l app.kubernetes.io/name=nifikop

# Check NiFi cluster status
kubectl describe nificluster edge-nifi -n nifi

# Check Zookeeper
kubectl logs -n nifi zookeeper-0
```

### ClickHouse connection issues

```bash
# Check ClickHouse pods
kubectl get pods -n clickhouse

# Test connection
kubectl exec -n clickhouse clickhouse-telemetry-db-0-0-0 -- \
  clickhouse-client --query="SELECT 1"
```

### Artemis MQTT issues

```bash
# Check Artemis logs
kubectl logs -l app=artemis-activemq-artemis

# Test MQTT connection
kubectl run mqtt-test --rm -it --image=eclipse-mosquitto:latest -- \
  mosquitto_sub -h artemis-activemq-artemis-master-0.artemis-activemq-artemis-master.default.svc.cluster.local \
  -t raw-telemetry -u admin -P admin
```

## Cleanup

```bash
# Uninstall all components
helm uninstall nifi -n nifi
helm uninstall clickhouse -n clickhouse
helm uninstall artemis-activemq
helm uninstall producer
helm uninstall nifikop -n nifi

# Delete namespaces
kubectl delete namespace nifi clickhouse
```

## References

- [Apache NiFi Documentation](https://nifi.apache.org/docs.html)
- [NiFiKop Operator](https://konpyutaika.github.io/nifikop/)
- [ClickHouse Documentation](https://clickhouse.com/docs)
- [ActiveMQ Artemis](https://activemq.apache.org/components/artemis/)
