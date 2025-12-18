# NiFi Flow Configuration Guide

This guide explains how to configure the NiFi data flow after deployment.

## Option 1: Manual Configuration (UI)

After deploying NiFi, access the UI and configure the following processors:

### 1. ConsumeMQTT Processor
- **Broker URI**: `tcp://artemis-broker.edge.svc.cluster.local:1883`
- **Client ID**: `nifi-mqtt-consumer`
- **Topic Filter**: `raw-telemetry`
- **QoS**: `1`
- **Username**: `admin`
- **Password**: `admin`
- **Max Queue Size**: `1000`

### 2. EvaluateJsonPath Processor
Extract fields from JSON messages:
- `timestamp`: `$.timestamp`
- `device_id`: `$.device_id`
- `temperature`: `$.temperature`
- `pressure`: `$.pressure`
- `status`: `$.status`
- `msg_id`: `$.msg_id`

### 3. ConvertRecord Processor (Optional)
Convert JSON to format suitable for ClickHouse insertion.

### 4. PutDatabaseRecord Processor
- **Database Connection Pooling Service**: `ClickHouseConnectionPool`
- **Statement Type**: `INSERT`
- **Table Name**: `telemetry.events`
- **Translate Field Names**: `true`
- **Field Containing SQL**: (leave empty)

### 5. ClickHouse Connection Pool Service
- **Database Connection URL**: `jdbc:clickhouse://clickhouse-telemetry-db.clickhouse.svc.cluster.local:8123/telemetry`
- **Database Driver Class Name**: `com.clickhouse.jdbc.ClickHouseDriver`
- **Database Driver Location**: `/opt/nifi/nifi-current/lib/clickhouse-jdbc-0.6.5-all.jar`
- **Database User**: `admin`
- **Password**: `password`

## Option 2: Automated Configuration (REST API)

NiFi provides a REST API to create flows programmatically.

### API Endpoint
```
http://localhost:8080/nifi-api
```

### Example: Create Flow via API

```bash
# 1. Get Process Group ID (root canvas)
PROCESS_GROUP_ID=$(curl -s http://localhost:8080/nifi-api/flow/process-groups/root | jq -r '.processGroupFlow.id')

# 2. Create ConsumeMQTT Processor
curl -X POST "http://localhost:8080/nifi-api/process-groups/${PROCESS_GROUP_ID}/processors" \
  -H "Content-Type: application/json" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "type": "org.apache.nifi.processors.mqtt.ConsumeMQTT",
      "name": "Consume MQTT Messages",
      "config": {
        "properties": {
          "Broker URI": "tcp://artemis-broker.edge.svc.cluster.local:1883",
          "Client ID": "nifi-mqtt-consumer",
          "Topic Filter": "raw-telemetry",
          "Quality of Service": "1",
          "Username": "admin",
          "Password": "admin"
        }
      }
    }
  }'

# 3. Create other processors similarly...
```

### NiFi Registry (Recommended for Production)

For production deployments, use **NiFi Registry** to version control flows:

1. **Export flow template** from UI
2. **Store in NiFi Registry**
3. **Deploy via API** or UI

```bash
# Deploy flow from registry
curl -X POST "http://localhost:8080/nifi-api/process-groups/${PROCESS_GROUP_ID}/process-groups" \
  -H "Content-Type: application/json" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "versionedFlowSnapshot": {
        "bucketId": "bucket-id",
        "flowId": "flow-id",
        "version": 1
      }
    }
  }'
```

### NiFi Toolkit (nipyapi)

Use Python library for easier API interaction:

```bash
pip install nipyapi
```

```python
import nipyapi

# Connect to NiFi
nipyapi.config.nifi_config.host = 'http://localhost:8080/nifi-api'

# Get root process group
root_pg = nipyapi.canvas.get_root_pg_id()

# Create processor
processor = nipyapi.canvas.create_processor(
    parent_pg=root_pg,
    processor_type='org.apache.nifi.processors.mqtt.ConsumeMQTT',
    location=(100, 100),
    name='Consume MQTT Messages',
    config={
        'Broker URI': 'tcp://artemis-broker.edge.svc.cluster.local:1883',
        'Topic Filter': 'raw-telemetry',
        'Username': 'admin',
        'Password': 'admin'
    }
)
```

## Flow Architecture

```
ConsumeMQTT → EvaluateJsonPath → ConvertRecord → PutDatabaseRecord → ClickHouse
                                                ↓
                                          LogAttribute (for debugging)
```

## Notes

- The ClickHouse JDBC driver is pre-installed via init container in the NiFi cluster CRD
- For production, use NiFi Registry to version control flows
- REST API documentation: http://localhost:8080/nifi-docs/rest-api/index.html
- Download nipyapi: https://github.com/Chaffelson/nipyapi

