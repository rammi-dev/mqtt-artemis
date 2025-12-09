# Industrial Telemetry Pipeline - Current Status

## 🎯 Objective
Deploy real-time telemetry pipeline: **Producer → Artemis → Kafka → Flink → ClickHouse**

## ✅ What's Working

### 1. Infrastructure Components
- **Artemis (ActiveMQ)**: ✅ Running in HA mode (master/slave)
- **Kafka Cluster**: ✅ Healthy (KRaft mode, Kafka 4.0.0, headless service working)
- **Flink**: ✅ Job running, connected to Kafka, ready to process
- **ClickHouse**: ✅ Database ready, Kafka Engine configured for `processed-events` topic
- **Topics**: ✅ `raw-telemetry` and `processed-events` created

### 2. Data Producer
- **Status**: ✅ Successfully sends 100 JSON messages to Artemis MQTT broker
- **Verification**: `kubectl logs job/producer-job-final`
- **Output**: Shows "Sent: {timestamp, device_id, temperature, pressure, status, msg_id}"

### 3. Flink Processing
- **Status**: ✅ PyFlink job running and connected
- **Source**: Configured to read from `raw-telemetry` Kafka topic
- **Sink**: Configured to write to `processed-events` Kafka topic
- **Verification**: `kubectl logs -n flink -l app=telemetry-etl -c flink-main-container`

### 4. ClickHouse Ingestion
- **Status**: ✅ Kafka Engine table configured
- **Configuration**: Materialized view consuming from `processed-events` topic
- **Schema**: Matches Flink output (timestamp, device_id, temperature, pressure, status, msg_id)

## ❌ What's NOT Working

### **BLOCKER: Artemis → Kafka Ingestion Layer**

**Problem**: No data flowing from Artemis to Kafka `raw-telemetry` topic

**Attempted Solutions** (6 different approaches):

#### Kafka Connect Attempts
1. **Apache Camel MQTT Connector v1-v3**: 
   - Error: `NoSuchMethodError: org.apache.kafka.common.utils.Utils.mkSet`
   - Root Cause: Camel connector 3.20.3 libraries incompatible with Kafka 4.0.0
   
2. **Lenses Stream Reactor v4-v5**:
   - Error: Connect pod crashes, REST API unresponsive
   - Root Cause: Connect startup failures, Kafka connection timeouts

#### Python Bridge Attempt
3. **Python MQTT-to-Kafka Bridge v6**:
   - Error: MQTT connection refused (code 5)
   - Tried: paho-mqtt<2.0.0, added credentials
   - Root Cause: Unknown - possibly Artemis security config or network policy

**Current Status**: 
```bash
# Kafka topic is empty
kubectl exec -n default telemetry-cluster-dual-role-0 -- \
  bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic raw-telemetry --from-beginning --max-messages 5
# Output: "Processed a total of 0 messages"

# ClickHouse is empty
kubectl exec -n clickhouse chi-telemetry-db-main-0-0-0 -- \
  clickhouse-client -u admin --password password \
  --query "SELECT count(*) FROM telemetry.events"
# Output: 0
```

## 🔍 Verification Commands

### Check Each Stage
```bash
# 1. Producer → Artemis (✅ WORKING)
kubectl logs job/producer-job-final --tail=20

# 2. Artemis → Kafka (❌ BLOCKED)
kubectl logs -n default -l app=bridge --tail=30

# 3. Kafka Topics
kubectl exec -n default telemetry-cluster-dual-role-0 -- \
  bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

# 4. Flink Status (✅ READY)
kubectl logs -n flink -l app=telemetry-etl -c flink-main-container --tail=30

# 5. ClickHouse Data (❌ EMPTY)
kubectl exec -n clickhouse chi-telemetry-db-main-0-0-0 -- \
  clickhouse-client -u admin --password password \
  --query "SELECT count(*) FROM telemetry.events"
```

## 📋 Next Steps (Options)

### Option 1: Debug Artemis MQTT (30 min)
- Check Artemis security configuration
- Test MQTT connectivity with simple client
- Verify network policies not blocking port 1883

### Option 2: Use Artemis JMS Instead (45 min)
- Create JMS-to-Kafka bridge (Java)
- More native to ActiveMQ Artemis

### Option 3: Direct Kafka Producer (15 min) ⭐ FASTEST
- Modify producer to send directly to Kafka
- Verify Flink → ClickHouse flow works
- Then fix Artemis ingestion separately

## 🏗️ Architecture Diagram
```
Producer ✅ → Artemis ✅ → [BLOCKED] → Kafka ✅ → Flink ✅ → ClickHouse ✅
                              ↑
                         Need working
                         ingestion layer
```
