# IoT Load Testing Tool for Apache Artemis

REST-driven load-testing platform focused on IoT protocols (MQTT, AMQP) with realistic device behavior.

## Features

- **Protocol Support**: MQTT, MQTT-WS, AMQP 1.0, HTTP/REST
- **Test Types**: Telemetry, Burst, Churn, Retained, Command, Offline, LWT
- **REST API**: Start/stop/monitor tests via FastAPI
- **Metrics**: Prometheus-compatible metrics endpoint
- **Safety Limits**: Server-side validation and limits
- **Role-Based Access Control**: Admin and test-telemetry roles

## Authentication & Authorization

The API uses Keycloak for authentication via OAuth2 Proxy. Access is controlled by roles:

### Users

| Username | Password | Role | Access |
|----------|----------|------|--------|
| `admin` | `admin` | admin | Full access to all endpoints |
| `test` | `test` | test-telemetry | Telemetry tests and viewing results only |

### Endpoint Permissions

| Endpoint | Method | admin | test-telemetry |
|----------|--------|-------|----------------|
| `/health` | GET | ✅ | ✅ (public) |
| `/metrics` | GET | ✅ | ✅ (public) |
| `/tests/telemetry` | POST | ✅ | ✅ |
| `/tests` | GET | ✅ | ✅ |
| `/tests/{job_id}` | GET | ✅ | ✅ |
| `/tests/burst` | POST | ✅ | ❌ |
| `/tests/churn` | POST | ✅ | ❌ |
| `/tests/retained` | POST | ✅ | ❌ |
| `/tests/command` | POST | ✅ | ❌ |
| `/tests/offline` | POST | ✅ | ❌ |
| `/tests/lwt` | POST | ✅ | ❌ |
| `/tests/amqp` | POST | ✅ | ❌ |
| `/tests` | POST | ✅ | ❌ |
| `/tests/{job_id}` | DELETE | ✅ | ❌ |

### Session Behavior

- Sessions expire when the browser is closed (session cookies)
- 30 minute idle timeout, 8 hour maximum session
- Users must log in again after closing the browser

## Quick Start

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run the API
uvicorn main:app --reload --port 8090

# OpenAPI docs at http://localhost:8090/docs
```

### Docker

```bash
# Build and push to Artifact Registry
./scripts/iot-load-tester/build.sh

# Deploy to GKE
./scripts/iot-load-tester/deploy.sh
```

### Kubernetes

```bash
helm install iot-load-tester ../charts/iot-load-tester -n edge
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/tests` | POST | Start a new load test |
| `/tests/{job_id}` | GET | Get job status |
| `/tests/{job_id}` | DELETE | Stop a running job |
| `/metrics` | GET | Prometheus metrics |
| `/health` | GET | Health check |
| `/docs` | GET | OpenAPI documentation |

## Example Request

```bash
curl -X POST http://localhost:8090/tests \
  -H "Content-Type: application/json" \
  -d '{"protocol": "mqtt", "brokerUrl": "mqtt://artemis:1883", "devices": 100, "runtimeSeconds": 60}'
```

## Test Type Examples

### Message Statistics (Standard Setup)

| Test Type | Devices | Runtime | Rate/Device | **Total Events** | **Events/Device** |
|-----------|---------|---------|-------------|------------------|-------------------|
| Telemetry | 100 | 60s | 1 msg/s | **6,000** | **60** |
| Burst | 1,000 | 120s | 1 msg/s (10x for 30s) | **150,000** | **150** |
| Churn | 500 | 120s | ~1 conn/10s | **6,000 connections** | **12 reconnects** |
| Retained | 100 | 60s | 1 msg/s | **6,000** | **60** |
| Command | 50 | 60s | 1 cmd/s | **6,000** (3k commands + 3k responses) | **120** |
| Offline | 100 | 120s | 1 msg/s | **12,000** | **120** |
| LWT | 100 | 60s | 1 disconnect | **100 LWT messages** | **1** |

### Sensor Data Behavior

Telemetry messages include **realistic sensor data** with temporal trends:

**Sensors Included:**
- `temperature`: 10-30°C baseline (per device) + gradual warming trend (+5°C/hour) + noise (±0.5°C)
- `humidity`: 35-65% baseline (per device) + 5-minute cycle (±10%) + noise (±2%)
- `pressure`: 1003-1023 hPa baseline (per device) + small noise (±0.5 hPa)

**Key Features:**
- **Seed-based**: Each device has consistent baseline values (reproducible)
- **Gradual changes**: Values trend over time, not random jumps
- **Realistic patterns**: Temperature warms, humidity cycles, pressure is stable

**Example payload:**
```json
{
  "deviceId": "device-00042-xkcd",
  "timestamp": 1735654321000,
  "temperature": 23.45,
  "humidity": 58.32,
  "pressure": 1015.67
}
```

### 1. Telemetry (default)
Devices periodically send sensor data.

**Events per device**: `runtimeSeconds × publishRatePerDevice` (default: 60 × 1 = **60 messages**)

**Available Parameters:**
- `devices`: 1-100,000 (default: 100)
- `publishRatePerDevice`: 0.1-100 msg/s (default: 1.0)
- `messageSizeBytes`: 1-1,048,576 bytes (default: 256)
- `topicPattern`: string (default: "devices/{deviceId}/telemetry")
- `qos`: 0-2 (default: 1)
- `messageExpirySeconds`: 1-86,400 seconds (optional, MQTT 5.0)
- `runtimeSeconds`: 10-3,600 seconds (default: 60)

```bash
curl -X POST https://loadtest.35.206.88.67.nip.io/tests/telemetry \
  -H "Content-Type: application/json" -d '{
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "devices": 100,
  "topicPattern": "devices/{deviceId}/telemetry",
  "qos": 1,
  "publishRatePerDevice": 1.0,
  "messageSizeBytes": 256,
  "messageExpirySeconds": 3600,
  "runtimeSeconds": 60
}'
```

### 2. Burst Traffic
Simulates synchronized traffic spikes.

**Events per device**: `(runtimeSeconds - burstDurationSeconds) × 1 + burstDurationSeconds × multiplier`  
(default: 90 × 1 + 30 × 10 = **390 messages**)

**Available Parameters:**
- `devices`: 1-100,000 (default: 1,000)
- `multiplier`: 1-100 (default: 10) - Traffic spike multiplier
- `burstDurationSeconds`: 1-300 seconds (default: 30)
- `messageExpirySeconds`: 1-86,400 seconds (optional, MQTT 5.0)
- `runtimeSeconds`: 10-3,600 seconds (default: 120)

```bash
curl -X POST https://loadtest.35.206.88.67.nip.io/tests/burst \
  -H "Content-Type: application/json" -d '{
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "devices": 1000,
  "multiplier": 10,
  "burstDurationSeconds": 30,
  "messageExpirySeconds": 120,
  "runtimeSeconds": 120
}'
```

### 3. Connection Churn
Simulates unstable devices connecting/disconnecting.

**Events per device**: `runtimeSeconds / 10` (default: 120 / 10 = **12 reconnects**)

**Available Parameters:**
- `devices`: 1-100,000 (default: 500)
- `runtimeSeconds`: 10-3,600 seconds (default: 120)

```bash
curl -X POST https://loadtest.35.206.88.67.nip.io/tests/churn \
  -H "Content-Type: application/json" -d '{
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "devices": 500,
  "runtimeSeconds": 120
}'
```

### 4. Retained Messages
Tests retained message fan-out under load.

**Events per device**: `runtimeSeconds × 1` (default: 60 × 1 = **60 messages**)

**Available Parameters:**
- `devices`: 1-100,000 (default: 100)
- `messageExpirySeconds`: 1-86,400 seconds (optional, MQTT 5.0)
- `runtimeSeconds`: 10-3,600 seconds (default: 60)

```bash
curl -X POST https://loadtest.35.206.88.67.nip.io/tests/retained \
  -H "Content-Type: application/json" -d '{
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "devices": 100,
  "messageExpirySeconds": 300,
  "runtimeSeconds": 60
}'
```

### 5. Command & Control
Backend sends commands, devices respond.

**Events per device**: `runtimeSeconds × 2` (1 command + 1 response per second, default: 60 × 2 = **120 messages**)

**Available Parameters:**
- `devices`: 1-100,000 (default: 50)
- `qos`: 0-2 (default: 1)
- `runtimeSeconds`: 10-3,600 seconds (default: 60)

```bash
curl -X POST https://loadtest.35.206.88.67.nip.io/tests/command \
  -H "Content-Type: application/json" -d '{
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "devices": 50,
  "qos": 1,
  "runtimeSeconds": 60
}'
```

### 6. Offline Device Backlog
Tests persistent sessions and message replay.

**Events per device**: `runtimeSeconds × 1` (default: 120 × 1 = **120 messages**)

**Available Parameters:**
- `devices`: 1-100,000 (default: 100)
- `qos`: 0-2 (default: 1)
- `runtimeSeconds`: 10-3,600 seconds (default: 120)

```bash
curl -X POST https://loadtest.35.206.88.67.nip.io/tests/offline \
  -H "Content-Type: application/json" -d '{
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "devices": 100,
  "qos": 1,
  "runtimeSeconds": 120
}'
```

### 7. Last Will & Testament (LWT)
Simulates unexpected device failures.

**Events per device**: **1 LWT message** per device

**Available Parameters:**
- `devices`: 1-100,000 (default: 100)
- `runtimeSeconds`: 10-3,600 seconds (default: 60)

```bash
curl -X POST https://loadtest.35.206.88.67.nip.io/tests/lwt \
  -H "Content-Type: application/json" -d '{
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "devices": 100,
  "runtimeSeconds": 60
}'
```

### AMQP 1.0 Example

**Available Parameters:**
- `devices`: 1-100,000 (default: 50)
- `runtimeSeconds`: 10-3,600 seconds (default: 60)

```bash
curl -X POST https://loadtest.35.206.88.67.nip.io/tests/amqp \
  -H "Content-Type: application/json" -d '{
  "brokerUrl": "amqp://artemis-amqp-0-svc.edge:5672",
  "devices": 50,
  "runtimeSeconds": 60
}'
```

## Safety Limits

| Parameter | Limit |
|-----------|-------|
| Devices | 100,000 |
| Connect rate | 2,000/sec |
| Publish rate | 50,000 msg/sec |
| Message size | 1 MB |
| Concurrent jobs | 5 |

