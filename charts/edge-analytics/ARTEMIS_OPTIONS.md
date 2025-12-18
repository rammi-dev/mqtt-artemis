# Edge Analytics - Artemis Deployment Options

## Artemis MQTT Broker Options

You have **3 options** for deploying Artemis:

### Option 1: ArkMQ Operator (RECOMMENDED ✅)
```yaml
# Official Apache ActiveMQ Artemis operator
dependencies:
  - name: arkmq-org-broker-operator
    version: "2.1.0"
    repository: "oci://quay.io/arkmq-org/helm-charts"
```
**Pros:**  
✅ Official open-source operator (Apache License 2.0)  
✅ CRD-based like NiFiKop and ClickHouse operator  
✅ Actively maintained (successor to ArtemisCloud)  
✅ Consistent operator pattern across all components  

**Cons:**  
⚠️ Requires creating ActiveMQArtemis CRD (similar to NiFiCluster)

### Option 2: Keep Existing Chart (Quick Start)
```yaml
# Use the local artemis chart (based on archived vromero project)
dependencies:
  - name: activemq-artemis
    repository: "file://../artemis"
```
**Pros:**  
✅ Already configured and tested  
✅ Works immediately  

**Cons:**  
⚠️ Based on archived vromero project  
⚠️ Need to maintain templates in repo

### Option 3: NimTechnology Chart
```yaml
# Community-maintained Helm chart
dependencies:
  - name: activemq
    version: "0.1.0"
    repository: "https://nimtechnology.github.io/activemq-helm-chart"
```
**Pros:**  
✅ Open source (Apache License 2.0)  
✅ Actively maintained (2024)  

**Cons:**  
⚠️ Not operator-based  
⚠️ Less consistent with NiFi/ClickHouse approach

## Recommendation

**Use ArkMQ Operator** - it's the official, open-source operator that matches your architecture pattern (operators for NiFi and ClickHouse).

All components would then be operator-managed:
- ✅ NiFiKop → manages NiFi
- ✅ ClickHouse Operator → manages ClickHouse  
- ✅ ArkMQ Operator → manages Artemis

This gives you consistent CRD-based management across the stack!
