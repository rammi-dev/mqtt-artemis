# Apache NiFi Deployment

Apache NiFi deployment with Keycloak OIDC authentication, ZooKeeper coordination, and Artemis MQTT/AMQP connectivity.

## Architecture

This deployment uses:
- **NiFiKop Operator**: Manages NiFi cluster lifecycle
- **ZooKeeper StatefulSet**: Provides cluster coordination (simplified deployment)
- **Keycloak OIDC**: Authentication and authorization
- **Artemis Integration**: MQTT/AMQP connectivity for IoT telemetry

> **Note**: ZooKeeper is deployed as a simple StatefulSet for development/testing.
> For production, consider using a ZooKeeper operator (Stackable, Pravega, etc.) for better
> management, high availability, and automated operations.

## Quick Start

```bash
# Deploy via deploy-gke.sh
./scripts/deploy-gke.sh nifi

# Or manually
helm upgrade --install nifi charts/infrastructure/nifi \
  --namespace nifi --create-namespace \
  --set domain=35.206.88.67.nip.io \
  --set nifi.global.oidc.oidc_url="https://keycloak.35.206.88.67.nip.io/realms/iot/.well-known/openid-configuration" \
  --set nifi.ingress.hostName="nifi.35.206.88.67.nip.io"
```

## Access

| URL | Description |
|-----|-------------|
| `https://nifi.<domain>/nifi` | NiFi UI |

## Authentication

Uses Keycloak OIDC with the same users as other services:

| User | Password | Role | NiFi Access |
|------|----------|------|-------------|
| admin | admin | nifi-admin | Full control |
| test | test | nifi-operator | View and operate flows |

## ZooKeeper

ZooKeeper is required by NiFi for cluster coordination. This deployment uses a simplified
StatefulSet approach suitable for development and testing.

### Configuration

| Setting | Value |
|---------|-------|
| Service | `nifi-zookeeper:2181` |
| Replicas | 1 (increase to 3+ for production) |
| Persistence | Enabled (8Gi per replica) |

### Production Considerations

For production deployments, consider:
- Using a ZooKeeper operator (Stackable, Pravega)
- Running 3+ replicas for high availability
- Configuring resource limits appropriately
- Enabling authentication and encryption

## Artemis Connectivity

NiFi can connect to Artemis to consume IoT telemetry messages.

### MQTT Connection

| Setting | Value |
|---------|-------|
| Broker URI | `tcp://artemis-mqtt-0-svc.edge.svc.cluster.local:1883` |
| Topic Filter | `devices/+/telemetry` |
| QoS | 1 |

### AMQP Connection

| Setting | Value |
|---------|-------|
| Connection String | `amqp://artemis-amqp-0-svc.edge.svc.cluster.local:5672` |
| Address | `devices.telemetry` |

### Credentials

Artemis credentials are stored in `artemis-credentials-secret` in the `edge` namespace.

To connect NiFi to Artemis:

1. In NiFi, add a **ConsumeMQTT** processor
2. Configure:
   - Broker URI: `tcp://artemis-mqtt-0-svc.edge.svc.cluster.local:1883`
   - Topic Filter: `devices/+/telemetry`
   - QoS: 1
3. Connect to downstream processors (LogMessage, PutFile, etc.)

## NiFi Flow Template

A sample flow for consuming Artemis telemetry:

```
ConsumeMQTT → EvaluateJsonPath → RouteOnAttribute → [Processing]
                                                  ↓
                                            LogMessage (debug)
```

### ConsumeMQTT Settings
- Broker URI: `tcp://artemis-mqtt-0-svc.edge.svc.cluster.local:1883`
- Client ID: `nifi-consumer`
- Topic Filter: `devices/+/telemetry`
- Max Queue Size: 1000

### EvaluateJsonPath Settings
- Destination: flowfile-attribute
- Extract:
  - `deviceId`: `$.deviceId`
  - `temperature`: `$.temperature`
  - `humidity`: `$.humidity`
  - `timestamp`: `$.timestamp`
