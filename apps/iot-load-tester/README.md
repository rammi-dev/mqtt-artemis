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

### 1. Telemetry (default)
Devices periodically send sensor data.
```bash
curl -X POST http://localhost:8090/tests -H "Content-Type: application/json" -d '{
  "protocol": "mqtt",
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "testType": "telemetry",
  "devices": 100,
  "topicPattern": "devices/{deviceId}/telemetry",
  "qos": 1,
  "publishRatePerDevice": 1.0,
  "messageSizeBytes": 256,
  "runtimeSeconds": 60
}'
```

### 2. Burst Traffic
Simulates synchronized traffic spikes.
```bash
curl -X POST http://localhost:8090/tests -H "Content-Type: application/json" -d '{
  "protocol": "mqtt",
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "testType": "burst",
  "devices": 1000,
  "burst": {"enabled": true, "multiplier": 10, "durationSeconds": 30},
  "runtimeSeconds": 120
}'
```

### 3. Connection Churn
Simulates unstable devices connecting/disconnecting.
```bash
curl -X POST http://localhost:8090/tests -H "Content-Type: application/json" -d '{
  "protocol": "mqtt",
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "testType": "churn",
  "devices": 500,
  "cleanSession": false,
  "runtimeSeconds": 120
}'
```

### 4. Retained Messages
Tests retained message fan-out under load.
```bash
curl -X POST http://localhost:8090/tests -H "Content-Type: application/json" -d '{
  "protocol": "mqtt",
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "testType": "retained",
  "devices": 100,
  "retain": true,
  "runtimeSeconds": 60
}'
```

### 5. Command & Control
Backend sends commands, devices respond.
```bash
curl -X POST http://localhost:8090/tests -H "Content-Type: application/json" -d '{
  "protocol": "mqtt",
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "testType": "command",
  "devices": 50,
  "qos": 1,
  "runtimeSeconds": 60
}'
```

### 6. Offline Device Backlog
Tests persistent sessions and message replay.
```bash
curl -X POST http://localhost:8090/tests -H "Content-Type: application/json" -d '{
  "protocol": "mqtt",
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "testType": "offline",
  "devices": 100,
  "cleanSession": false,
  "qos": 1,
  "runtimeSeconds": 120
}'
```

### 7. Last Will & Testament (LWT)
Simulates unexpected device failures.
```bash
curl -X POST http://localhost:8090/tests -H "Content-Type: application/json" -d '{
  "protocol": "mqtt",
  "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
  "testType": "lwt",
  "devices": 100,
  "runtimeSeconds": 60
}'
```

### AMQP 1.0 Example
```bash
curl -X POST http://localhost:8090/tests -H "Content-Type: application/json" -d '{
  "protocol": "amqp",
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

