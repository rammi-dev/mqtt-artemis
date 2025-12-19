# Edge Analytics Dagster Pipelines

This directory contains Dagster pipelines for data orchestration and ClickHouse management.

## Structure

```
dagster/
├── Dockerfile              # Container image for pipeline code
├── pipelines/
│   ├── __init__.py        # Dagster Definitions
│   ├── assets.py          # Data assets (ClickHouse → Redis sync, aggregations)
│   ├── jobs.py            # Job definitions
│   ├── schedules.py       # Cron schedules
│   ├── sensors.py         # Event-driven triggers
│   └── resources.py       # ClickHouse/Redis connections
```

## Jobs & Schedules

| Job | Schedule | Description |
|-----|----------|-------------|
| `redis_sync_job` | Every minute | Sync ClickHouse aggregations → Redis |
| `hourly_aggregation_job` | Hourly (5 min past) | Verify hourly materialized views |
| `daily_aggregation_job` | Daily 1 AM | Generate daily device summaries |
| `clickhouse_maintenance_job` | Daily 3 AM | Optimize tables, cleanup partitions |
| `data_quality_job` | Hourly | Monitor data quality metrics |

## Sensors

| Sensor | Trigger | Description |
|--------|---------|-------------|
| `high_volume_sensor` | >1000 events/min | Extra Redis sync during spikes |
| `data_freshness_sensor` | No data >5 min | Alert on stale data |

## Assets

### Redis Cache Group
- `device_stats_cache` - Per-device statistics (5 min window)
- `timeseries_cache` - 1-hour time-series (1 min resolution)
- `system_health_cache` - Overall health metrics
- `hourly_stats_cache` - 24-hour hourly aggregations

### ClickHouse Aggregations
- `hourly_aggregation` - Track hourly materialized view
- `daily_device_summary` - Daily device reports

### ClickHouse Maintenance
- `optimize_tables` - Merge parts for performance
- `table_sizes` - Monitor storage usage
- `partition_cleanup` - TTL enforcement

### Data Quality
- `data_quality_metrics` - Completeness, outliers, anomalies

## Building the Docker Image

```bash
cd charts/edge-analytics/dagster
docker build -t edge-analytics/dagster-pipelines:latest .

# Push to your registry
docker tag edge-analytics/dagster-pipelines:latest your-registry/dagster-pipelines:latest
docker push your-registry/dagster-pipelines:latest
```

## Local Development

```bash
# Install dependencies
pip install dagster dagster-webserver clickhouse-connect redis

# Set environment variables
export CLICKHOUSE_HOST=localhost
export CLICKHOUSE_PORT=8123
export CLICKHOUSE_USER=admin
export CLICKHOUSE_PASSWORD=password
export REDIS_HOST=localhost
export REDIS_PORT=6379
export REDIS_PASSWORD=redis-secret

# Run Dagster dev server
cd charts/edge-analytics/dagster
dagster dev -m pipelines
```

Open http://localhost:3000 for Dagster UI.

## Accessing Dagster UI (Deployed)

```bash
kubectl port-forward -n edge svc/edge-analytics-dagster-webserver 3000:80
```

Open http://localhost:3000

## Triggering Jobs Manually

Via UI:
1. Open Dagster UI
2. Navigate to Jobs → Select job → Launch Run

Via CLI:
```bash
# Port-forward the webserver
kubectl port-forward -n edge svc/edge-analytics-dagster-webserver 3000:80

# Trigger via dagster CLI
dagster job execute -m pipelines -j redis_sync_job
```

## Benefits over CronJob

| Feature | CronJob | Dagster |
|---------|---------|---------|
| Observability | Logs only | Full UI, lineage, metrics |
| Retry logic | Manual | Built-in configurable |
| Dependencies | None | Asset dependencies |
| Alerting | External | Integrated |
| Backfills | Manual | One-click |
| Scheduling | Cron only | Cron + sensors + events |
| Testing | Difficult | First-class support |
