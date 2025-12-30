# IoT Load Tester Helm Chart

Helm chart for deploying the IoT Load Testing Tool on Kubernetes.

## Installation

```bash
# Get your ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Install with dynamic domain
helm install iot-load-tester . -n edge --set domain="${INGRESS_IP}.nip.io"
```

## Access

Once deployed, access the tool at:
- OpenAPI: `https://loadtest.<ingress-ip>.nip.io/docs`
- Redoc: `https://loadtest.<ingress-ip>.nip.io/redoc`
- Metrics: `https://loadtest.<ingress-ip>.nip.io/metrics`

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `domain` | Ingress domain | `""` |
| `ingress.enabled` | Enable ingress | `true` |
| `artemis.mqttHost` | Artemis MQTT host | `artemis-mqtt-0-svc.edge` |
| `safetyLimits.maxDevices` | Max devices per test | `100000` |

## Example Usage

```bash
# Start a test
curl -X POST https://loadtest.<ip>.nip.io/tests \
  -H "Content-Type: application/json" \
  -d '{
    "protocol": "mqtt",
    "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
    "devices": 100,
    "runtimeSeconds": 60
  }'
```
