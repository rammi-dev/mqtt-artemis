# Edge Analytics - Optimization Recommendations

This document outlines recommended optimizations for the edge analytics platform.

## 1. Data Pipeline Optimizations

### 1.1 NiFi Flow Optimization

**Current State**: Basic MQTT → ClickHouse flow

**Recommendations**:

```yaml
# Add batch processing in NiFi (reduces ClickHouse insert overhead)
MergeContent Processor:
  - Minimum Entries: 100
  - Maximum Entries: 1000
  - Max Bin Age: 5 sec
```

- **Batch Inserts**: Configure NiFi to batch messages before inserting into ClickHouse (100-1000 messages per batch)
- **Back-pressure**: Set appropriate back-pressure thresholds to prevent memory overflow
- **Connection Pooling**: Use connection pooling for ClickHouse JDBC connections (pool size: 5-10)

### 1.2 ClickHouse Optimization

**Schema Improvements**:

```sql
-- Current schema (optimized version)
CREATE TABLE telemetry.events (
    timestamp DateTime64(3) CODEC(DoubleDelta),  -- Efficient timestamp compression
    device_id LowCardinality(String),             -- Optimize for repeated device IDs
    temperature Float32 CODEC(Gorilla),           -- Better compression for metrics
    pressure Float32 CODEC(Gorilla),
    status LowCardinality(String),                -- Only 'OK' or 'WARN'
    msg_id UInt64 CODEC(Delta)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)                  -- Monthly partitions
ORDER BY (device_id, timestamp)                   -- Optimized for device queries
TTL timestamp + INTERVAL 90 DAY;                  -- Auto-expire old data
```

**Materialized Views** (pre-aggregate for dashboards):

```sql
-- 1-minute aggregations
CREATE MATERIALIZED VIEW telemetry.events_1m
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMMDD(timestamp)
ORDER BY (device_id, timestamp)
AS SELECT
    toStartOfMinute(timestamp) as timestamp,
    device_id,
    count() as events,
    sum(temperature) as sum_temp,
    sum(pressure) as sum_pressure,
    countIf(status = 'WARN') as warnings
FROM telemetry.events
GROUP BY device_id, toStartOfMinute(timestamp);
```

### 1.3 Redis Optimization

**Current**: Basic key-value caching

**Recommendations**:

```yaml
# Use Redis Streams for real-time updates (instead of CronJob)
redis:
  commonConfiguration: |-
    maxmemory 500mb
    maxmemory-policy volatile-lru
    stream-node-max-bytes 4096
    stream-node-max-entries 100
```

- **Redis Streams**: Push real-time events for live dashboards
- **Pub/Sub**: Notify dashboards of data updates
- **Sorted Sets**: For time-series leaderboards (top devices by temperature, etc.)

## 2. Infrastructure Optimizations

### 2.1 Resource Sizing

| Component | Current | Recommended (Edge) | Recommended (Production) |
|-----------|---------|-------------------|-------------------------|
| NiFi | 1Gi/500m | 2Gi/1000m | 4Gi/2000m |
| ClickHouse | 512Mi/500m | 1Gi/1000m | 4Gi/2000m |
| Redis | 128Mi/100m | 256Mi/250m | 512Mi/500m |
| Zookeeper | 256Mi/250m | 512Mi/500m | 1Gi/1000m |

### 2.2 Persistence Strategy

```yaml
# ClickHouse - Use local SSDs for performance
clickhouse:
  persistence:
    storageClass: "local-ssd"   # Or fast storage class
    size: 1Gi
    
# Redis - Disable persistence for pure cache (faster)
redis:
  master:
    persistence:
      enabled: false  # If used only as cache
```

### 2.3 Network Optimization

```yaml
# Enable host networking for Artemis (if high throughput needed)
artemis:
  hostNetwork: true  # Reduces network latency
  
# Use headless services where appropriate
service:
  type: ClusterIP
  headless: true
```

## 3. Monitoring & Observability

### 3.1 Add Prometheus Metrics

```yaml
# values.yaml additions
prometheus:
  enabled: true
  
# NiFi metrics
nifi:
  metrics:
    enabled: true
    port: 9092
    
# ClickHouse metrics
clickhouse:
  metrics:
    enabled: true
    port: 9363
```

### 3.2 Grafana with ClickHouse Datasource

Grafana reads directly from ClickHouse for real-time analytics:

```yaml
# Grafana datasource configuration
grafana:
  datasources:
    datasources.yaml:
      datasources:
        - name: ClickHouse
          type: grafana-clickhouse-datasource
          url: http://clickhouse-telemetry-db:8123
          jsonData:
            defaultDatabase: telemetry
          secureJsonData:
            password: password
  plugins:
    - grafana-clickhouse-datasource
```

### 3.3 Optimized ClickHouse Queries for Grafana

**Fast Dashboard Queries** (use materialized views):

```sql
-- Events per minute (uses aggregated view)
SELECT timestamp, sum(events) as events 
FROM telemetry.events_1m 
WHERE timestamp >= now() - INTERVAL 1 HOUR 
GROUP BY timestamp ORDER BY timestamp;

-- Device stats (uses pre-aggregated data)
SELECT device_id, 
       sum(sum_temp)/sum(events) as avg_temp,
       sum(warnings) as total_warnings
FROM telemetry.events_1m 
WHERE timestamp >= now() - INTERVAL 1 HOUR
GROUP BY device_id;
```

**System Health Queries** (for monitoring panels):

```sql
-- Data freshness (lag detection)
SELECT dateDiff('second', max(timestamp), now()) as lag_seconds 
FROM telemetry.events;

-- Warning rate percentage
SELECT round(countIf(status = 'WARN') * 100.0 / count(), 2) as warning_pct 
FROM telemetry.events 
WHERE timestamp >= now() - INTERVAL 5 MINUTE;

-- Partition health
SELECT partition, count() as parts, sum(rows) as total_rows,
       formatReadableSize(sum(bytes_on_disk)) as size 
FROM system.parts 
WHERE database = 'telemetry' AND active 
GROUP BY partition ORDER BY partition DESC;
```

### 3.4 Grafana Dashboard Best Practices

| Query Type | Data Source | Refresh | Use Case |
|------------|-------------|---------|----------|
| Real-time events | ClickHouse | 10s | Live event feed |
| Time-series graphs | ClickHouse MV | 30s | Trend visualization |
| Aggregated stats | Redis | 5s | Fast counters |
| System metrics | Prometheus | 15s | Infrastructure health |

**Panel Optimization Tips**:

1. **Use `$__timeFilter`** macro for time range filtering
2. **Limit results**: Always use `LIMIT` in table queries
3. **Prefer materialized views** for time-series panels
4. **Cache with Redis** for frequently accessed aggregations
5. **Set appropriate intervals**: Don't query at higher resolution than data

### 3.5 Pre-built Grafana Dashboards

1. **Edge Analytics Overview**:
   - System CPU/Memory (Prometheus)
   - Active devices (ClickHouse)
   - Events per minute (ClickHouse)
   - Temperature by device (ClickHouse)
   - Event status distribution (ClickHouse)
   - Device status table (ClickHouse)

2. **ClickHouse Metrics**:
   - Insert rate (Prometheus)
   - Active queries (Prometheus)
   - Storage size (ClickHouse `system.parts`)
   - Events per device (ClickHouse)
   - Query performance log (ClickHouse `system.query_log`)
   - Partition info (ClickHouse)

3. **Pipeline Health**:
   - NiFi queue depth (Prometheus)
   - Redis memory (Prometheus)
   - Data freshness lag (ClickHouse)
   - Warning rate (ClickHouse)
   - Temperature anomalies (ClickHouse)
   - Device uptime heatmap (ClickHouse)

## 4. High Availability (Production)

### 4.1 ClickHouse Cluster

```yaml
# clickhouse-cluster.yaml - HA configuration
spec:
  configuration:
    clusters:
      - name: main
        layout:
          shardsCount: 2      # Data sharding
          replicasCount: 2    # Per-shard replicas
```

### 4.2 Redis Sentinel/Cluster

```yaml
# values.yaml - HA Redis
redis:
  architecture: replication
  sentinel:
    enabled: true
    quorum: 2
  replica:
    replicaCount: 2
```

### 4.3 NiFi Cluster

```yaml
# nifi-cluster.yaml - Multi-node
spec:
  nodes:
    - id: 0
      nodeConfigGroup: "default"
    - id: 1
      nodeConfigGroup: "default"
    - id: 2
      nodeConfigGroup: "default"
```

## 5. Security Hardening

### 5.1 Enable TLS

```yaml
# All services should use TLS in production
nifi:
  listenersConfig:
    internalListeners:
      - type: "https"
        containerPort: 8443
    sslSecrets:
      create: true
      
clickhouse:
  configuration:
    settings:
      https_port: 8443
      
redis:
  tls:
    enabled: true
```

### 5.2 Secret Management

```yaml
# Use external secrets operator
externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
```

### 5.3 Network Policies

```yaml
# Restrict pod-to-pod communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: edge-analytics-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/part-of: edge-analytics
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: edge
```

## 6. Cost Optimization

### 6.1 Data Retention

```sql
-- ClickHouse TTL for automatic data cleanup
ALTER TABLE telemetry.events
    MODIFY TTL timestamp + INTERVAL 30 DAY;

-- Archive old data to cold storage
CREATE TABLE telemetry.events_archive
ENGINE = S3('s3://bucket/archive/', 'key', 'secret', 'Parquet');
```

### 6.2 Resource Autoscaling

```yaml
# HPA for Dashboard API
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dashboard-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dashboard-api
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

## 7. Grafana-ClickHouse Performance Tuning

### 7.1 Query Optimization for Dashboards

**Problem**: Direct queries on raw data are slow for dashboards

**Solution**: Use tiered query strategy

```sql
-- Create indexes for common dashboard filters
ALTER TABLE telemetry.events ADD INDEX idx_status status TYPE set(100) GRANULARITY 4;
ALTER TABLE telemetry.events ADD INDEX idx_device device_id TYPE bloom_filter() GRANULARITY 4;

-- Materialized view for Grafana time-series panels
CREATE MATERIALIZED VIEW telemetry.grafana_timeseries
ENGINE = SummingMergeTree()
PARTITION BY toDate(timestamp)
ORDER BY (timestamp, device_id)
AS SELECT
    toStartOfMinute(timestamp) as timestamp,
    device_id,
    count() as event_count,
    sum(temperature) as sum_temp,
    min(temperature) as min_temp,
    max(temperature) as max_temp,
    sum(pressure) as sum_pressure,
    countIf(status = 'WARN') as warnings,
    countIf(status = 'OK') as ok_count
FROM telemetry.events
GROUP BY timestamp, device_id;
```

### 7.2 Grafana Variable Optimization

```sql
-- Fast device dropdown (cached)
SELECT DISTINCT device_id FROM telemetry.events 
WHERE timestamp >= now() - INTERVAL 1 DAY
SETTINGS max_execution_time = 5;

-- Use dictionary for device metadata
CREATE DICTIONARY telemetry.device_dict (
    device_id String,
    device_name String,
    location String
) PRIMARY KEY device_id
SOURCE(CLICKHOUSE(TABLE 'device_metadata'))
LAYOUT(FLAT())
LIFETIME(MIN 300 MAX 600);
```

### 7.3 Dashboard Query Cache

```yaml
# ClickHouse query cache settings
clickhouse:
  configuration:
    users:
      grafana:
        profile: grafana_profile
    profiles:
      grafana_profile:
        use_query_cache: 1
        query_cache_ttl: 60
        query_cache_share_between_users: 1
        max_execution_time: 30
```

## 8. Quick Wins (Implement First)

1. ✅ **Redis caching** - Already implemented
2. ✅ **Grafana + ClickHouse** - Direct analytics dashboards
3. ✅ **Prometheus monitoring** - System metrics
4. ⬜ **ClickHouse LowCardinality** - Simple schema change, big impact
5. ⬜ **NiFi batch inserts** - Configure MergeContent processor
6. ⬜ **Data TTL** - Add TTL to prevent unbounded growth
7. ⬜ **Materialized views** - Pre-aggregate for Grafana
8. ⬜ **Query cache** - Enable ClickHouse query cache for Grafana

## 9. Performance Benchmarks

| Metric | Current (Est.) | Optimized Target |
|--------|----------------|------------------|
| Insert rate | ~100 msg/s | 10,000+ msg/s |
| Query latency (dashboard) | 500-2000ms | <10ms (Redis) |
| Grafana panel load (raw) | 2-5s | <500ms (MV) |
| Grafana panel load (cached) | 500ms | <100ms (query cache) |
| Storage efficiency | ~50 bytes/event | ~15 bytes/event |
| Recovery time | Manual | <30 seconds (HA) |
| Data freshness | Unknown | <60s monitored |

## 10. Implementation Priority

| Priority | Optimization | Effort | Impact | Status |
|----------|-------------|--------|--------|--------|
| 1 | Redis dashboard cache | Low | High | ✅ Done |
| 2 | Grafana + ClickHouse datasource | Low | High | ✅ Done |
| 3 | Prometheus monitoring | Low | Medium | ✅ Done |
| 4 | Dagster orchestration | Medium | High | ✅ Done |
| 5 | ClickHouse schema optimization | Low | High | ⬜ Pending |
| 6 | NiFi batch processing | Medium | High | ⬜ Pending |
| 7 | Materialized views for Grafana | Medium | High | ⬜ Pending |
| 8 | ClickHouse query cache | Low | Medium | ⬜ Pending |
| 9 | HA configuration | High | High | ⬜ Pending |
| 10 | TLS/Security | High | Medium | ⬜ Pending |
