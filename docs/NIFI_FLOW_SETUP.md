# NiFi Flow Configuration Guide

This guide explains how to configure the NiFi data flow after deployment.

## Recommended Flow Architecture (Batched)

```
ConsumeMQTT → EvaluateJsonPath → MergeContent (batch) → PutDatabaseRecord → ClickHouse
                                        ↓
                                 PublishRedis (real-time) → Redis → Dashboard API
```

**Key Features**:
- **Batched inserts** to ClickHouse (100-500 messages per batch)
- **Real-time streaming** to Redis for ultra-fast dashboards
- **Dual write pattern** for both historical storage and live views

---

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

### 3. MergeContent Processor (BATCHING - Critical for Performance)
Batch messages before ClickHouse insert:
- **Merge Strategy**: `Bin-Packing Algorithm`
- **Merge Format**: `Binary Concatenation`
- **Minimum Number of Entries**: `100`
- **Maximum Number of Entries**: `500`
- **Max Bin Age**: `5 sec`
- **Delimiter Strategy**: `Text`
- **Header**: (empty)
- **Footer**: (empty)
- **Demarcator**: `\n` (newline - creates NDJSON)

> **Why batch?** ClickHouse performs best with bulk inserts. Batching 100-500 records reduces insert overhead by 10-50x.

### 4. ConvertRecord Processor (Optional)
Convert JSON to format suitable for ClickHouse insertion.

### 5. PutDatabaseRecord Processor
- **Database Connection Pooling Service**: `ClickHouseConnectionPool`
- **Statement Type**: `INSERT`
- **Table Name**: `telemetry.events`
- **Translate Field Names**: `true`
- **Field Containing SQL**: (leave empty)
- **Batch Size**: `500` (match MergeContent max entries)

### 6. ClickHouse Connection Pool Service
- **Database Connection URL**: `jdbc:clickhouse://clickhouse-telemetry-db.clickhouse.svc.cluster.local:8123/telemetry`
- **Database Driver Class Name**: `com.clickhouse.jdbc.ClickHouseDriver`
- **Database Driver Location**: `/opt/nifi/nifi-current/lib/clickhouse-jdbc-0.6.5-all.jar`
- **Database User**: `admin`
- **Password**: `password`
- **Max Wait Time**: `500 millis`
- **Max Total Connections**: `10`

---

## Redis Real-Time Stream (Ultra-Fast Dashboards)

For live dashboard updates, add a Redis branch to your flow:

### 7. PublishRedis Processor (After EvaluateJsonPath)
Send each message to Redis for real-time consumption:
- **Redis Mode**: `Standalone`
- **Redis Connection String**: `edge-analytics-redis-master.edge.svc.cluster.local:6379`
- **Redis Password**: `redis-secret`
- **Channel/Key**: `telemetry:live`
- **Data Type**: `Publish` (Pub/Sub for real-time)

### 8. Alternative: PutRedisStreamEntry (For Replay)
Use Redis Streams for buffered real-time data:
- **Redis Connection String**: `edge-analytics-redis-master.edge.svc.cluster.local:6379`
- **Redis Password**: `redis-secret`
- **Stream Name**: `telemetry:stream`
- **Max Stream Length**: `10000` (keep last 10k events)

### 9. Redis Hash for Latest Device State
Update device state in Redis Hash:
- **Key**: `device:${device_id}`
- **Hash Fields**: temperature, pressure, status, timestamp
- **TTL**: `300` (5 minutes - auto-expire inactive devices)

---

## Complete Flow Diagram

```
                                    ┌─────────────────────┐
                                    │   PublishRedis      │
                                    │ (telemetry:live)    │──→ Pub/Sub → Dashboard
                                    └─────────────────────┘
                                              ↑
┌──────────────┐    ┌───────────────────┐    │
│ ConsumeMQTT  │───→│ EvaluateJsonPath  │────┼─────────────────────────────────────┐
│ (raw-telemetry)   │ (extract fields)  │    │                                     │
└──────────────┘    └───────────────────┘    │                                     │
                                              ↓                                     ↓
                                    ┌─────────────────────┐              ┌─────────────────────┐
                                    │  PutRedisHashRecord │              │    MergeContent     │
                                    │ (device:${id})      │              │   (batch 100-500)   │
                                    └─────────────────────┘              └─────────────────────┘
                                                                                   │
                                                                                   ↓
                                                                         ┌─────────────────────┐
                                                                         │ PutDatabaseRecord   │
                                                                         │   (ClickHouse)      │
                                                                         └─────────────────────┘
```

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
ConsumeMQTT → EvaluateJsonPath → MergeContent → PutDatabaseRecord → ClickHouse
                    ↓                                    
              PublishRedis ──→ Redis (real-time) ──→ Dashboard
```

**Data Paths**:
1. **Historical Path**: MQTT → NiFi (batch) → ClickHouse (bulk insert)
2. **Real-time Path**: MQTT → NiFi → Redis (instant) → Dashboard

## Performance Comparison

| Approach | Latency | Throughput | Use Case |
|----------|---------|------------|----------|
| Direct ClickHouse | 50-200ms | ~1,000/s | Historical queries |
| Batched ClickHouse | 5-50ms/batch | ~50,000/s | Bulk storage |
| Redis Pub/Sub | <1ms | ~100,000/s | Live dashboards |
| Redis Hash | <1ms | ~100,000/s | Device current state |

## Notes

- The ClickHouse JDBC driver is pre-installed via init container in the NiFi cluster CRD
- For production, use NiFi Registry to version control flows
- REST API documentation: http://localhost:8080/nifi-docs/rest-api/index.html
- Download nipyapi: https://github.com/Chaffelson/nipyapi

