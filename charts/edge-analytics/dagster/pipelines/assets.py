"""
Dagster Assets for Edge Analytics

Assets represent data artifacts that are produced and tracked by Dagster.
"""

from dagster import asset, AssetExecutionContext, MetadataValue, Output
from datetime import datetime, timedelta
import json


# ============================================
# REDIS SYNC ASSETS (Dashboard Cache)
# ============================================

@asset(
    group_name="redis_cache",
    description="Device statistics aggregated from ClickHouse for dashboard display",
    compute_kind="python",
)
def device_stats_cache(context: AssetExecutionContext):
    """
    Sync device statistics from ClickHouse to Redis.
    Updates every minute for near-real-time dashboard data.
    """
    clickhouse = context.resources.clickhouse
    redis = context.resources.redis
    
    query = """
    SELECT 
        device_id,
        count() as message_count,
        round(avg(temperature), 2) as avg_temperature,
        round(min(temperature), 2) as min_temperature,
        round(max(temperature), 2) as max_temperature,
        round(avg(pressure), 2) as avg_pressure,
        countIf(status = 'WARN') as warning_count
    FROM events
    WHERE timestamp >= now() - INTERVAL 5 MINUTE
    GROUP BY device_id
    ORDER BY device_id
    """
    
    result = clickhouse.execute(query)
    device_stats = [
        {
            'device_id': row[0],
            'message_count': row[1],
            'avg_temperature': row[2],
            'min_temperature': row[3],
            'max_temperature': row[4],
            'avg_pressure': row[5],
            'warning_count': row[6]
        }
        for row in result.result_rows
    ]
    
    redis.set_json('dashboard:device_stats', device_stats, ttl=120)
    
    context.log.info(f"Cached device_stats: {len(device_stats)} devices")
    
    return Output(
        value=len(device_stats),
        metadata={
            "device_count": MetadataValue.int(len(device_stats)),
            "cache_key": MetadataValue.text("dashboard:device_stats"),
            "ttl_seconds": MetadataValue.int(120),
        }
    )


@asset(
    group_name="redis_cache",
    description="Time-series data (1 hour) for dashboard charts",
    compute_kind="python",
)
def timeseries_cache(context: AssetExecutionContext):
    """
    Sync 1-hour time-series data from ClickHouse to Redis.
    1-minute resolution for detailed charts.
    """
    clickhouse = context.resources.clickhouse
    redis = context.resources.redis
    
    query = """
    SELECT 
        toStartOfMinute(timestamp) as minute,
        round(avg(temperature), 2) as avg_temp,
        round(avg(pressure), 2) as avg_pressure,
        count() as events
    FROM events
    WHERE timestamp >= now() - INTERVAL 1 HOUR
    GROUP BY minute
    ORDER BY minute
    """
    
    result = clickhouse.execute(query)
    timeseries = [
        {
            'timestamp': row[0].isoformat(),
            'avg_temperature': row[1],
            'avg_pressure': row[2],
            'event_count': row[3]
        }
        for row in result.result_rows
    ]
    
    redis.set_json('dashboard:timeseries_1h', timeseries, ttl=120)
    
    context.log.info(f"Cached timeseries: {len(timeseries)} data points")
    
    return Output(
        value=len(timeseries),
        metadata={
            "data_points": MetadataValue.int(len(timeseries)),
            "cache_key": MetadataValue.text("dashboard:timeseries_1h"),
        }
    )


@asset(
    group_name="redis_cache",
    description="System health metrics for dashboard overview",
    compute_kind="python",
)
def system_health_cache(context: AssetExecutionContext):
    """
    Sync overall system health metrics to Redis.
    Provides quick health status for dashboards.
    """
    clickhouse = context.resources.clickhouse
    redis = context.resources.redis
    
    query = """
    SELECT 
        count() as total_events,
        countIf(status = 'OK') as ok_count,
        countIf(status = 'WARN') as warn_count,
        uniq(device_id) as active_devices,
        round(avg(temperature), 2) as avg_temp,
        round(avg(pressure), 2) as avg_pressure
    FROM events
    WHERE timestamp >= now() - INTERVAL 5 MINUTE
    """
    
    result = clickhouse.execute(query)
    
    if result.result_rows:
        row = result.result_rows[0]
        health = {
            'total_events': row[0],
            'ok_count': row[1],
            'warn_count': row[2],
            'active_devices': row[3],
            'avg_temperature': row[4],
            'avg_pressure': row[5],
            'health_score': round((row[1] / max(row[0], 1)) * 100, 1),
            'updated_at': datetime.now().isoformat()
        }
        redis.set_json('dashboard:system_health', health, ttl=120)
        
        context.log.info(f"Cached system_health: health_score={health['health_score']}%")
        
        return Output(
            value=health,
            metadata={
                "total_events": MetadataValue.int(health['total_events']),
                "active_devices": MetadataValue.int(health['active_devices']),
                "health_score": MetadataValue.float(health['health_score']),
            }
        )
    
    return Output(value={}, metadata={"status": MetadataValue.text("no_data")})


@asset(
    group_name="redis_cache",
    description="Hourly statistics for 24-hour trends",
    compute_kind="python",
)
def hourly_stats_cache(context: AssetExecutionContext):
    """
    Sync 24-hour hourly aggregations to Redis.
    For trend analysis and historical charts.
    """
    clickhouse = context.resources.clickhouse
    redis = context.resources.redis
    
    query = """
    SELECT 
        toStartOfHour(timestamp) as hour,
        count() as events,
        round(avg(temperature), 2) as avg_temp,
        round(avg(pressure), 2) as avg_pressure,
        uniq(device_id) as devices
    FROM events
    WHERE timestamp >= now() - INTERVAL 24 HOUR
    GROUP BY hour
    ORDER BY hour
    """
    
    result = clickhouse.execute(query)
    hourly_stats = [
        {
            'hour': row[0].isoformat(),
            'events': row[1],
            'avg_temperature': row[2],
            'avg_pressure': row[3],
            'active_devices': row[4]
        }
        for row in result.result_rows
    ]
    
    redis.set_json('dashboard:hourly_stats_24h', hourly_stats, ttl=300)
    
    context.log.info(f"Cached hourly_stats: {len(hourly_stats)} hours")
    
    return Output(
        value=len(hourly_stats),
        metadata={
            "hours": MetadataValue.int(len(hourly_stats)),
            "cache_key": MetadataValue.text("dashboard:hourly_stats_24h"),
        }
    )


# ============================================
# CLICKHOUSE AGGREGATION ASSETS
# ============================================

@asset(
    group_name="clickhouse_aggregations",
    description="Hourly aggregation materialized view refresh",
    compute_kind="clickhouse",
)
def hourly_aggregation(context: AssetExecutionContext):
    """
    Ensure hourly aggregations are up to date.
    ClickHouse materialized views handle this automatically,
    but we track it as an asset for observability.
    """
    clickhouse = context.resources.clickhouse
    
    # Check materialized view status
    query = """
    SELECT 
        count() as row_count,
        min(hour) as earliest,
        max(hour) as latest
    FROM telemetry.events_hourly
    WHERE hour >= now() - INTERVAL 24 HOUR
    """
    
    result = clickhouse.execute(query)
    
    if result.result_rows:
        row = result.result_rows[0]
        context.log.info(f"Hourly aggregations: {row[0]} rows, range: {row[1]} to {row[2]}")
        
        return Output(
            value=row[0],
            metadata={
                "row_count": MetadataValue.int(row[0]),
                "earliest_hour": MetadataValue.text(str(row[1])),
                "latest_hour": MetadataValue.text(str(row[2])),
            }
        )
    
    return Output(value=0)


@asset(
    group_name="clickhouse_aggregations",
    description="Daily device summary aggregation",
    compute_kind="clickhouse",
)
def daily_device_summary(context: AssetExecutionContext):
    """
    Generate daily device summaries for reporting.
    """
    clickhouse = context.resources.clickhouse
    
    query = """
    SELECT 
        count() as row_count,
        uniq(device_id) as unique_devices,
        min(date) as earliest,
        max(date) as latest
    FROM telemetry.device_daily_summary
    WHERE date >= today() - 30
    """
    
    result = clickhouse.execute(query)
    
    if result.result_rows:
        row = result.result_rows[0]
        context.log.info(f"Daily summaries: {row[0]} rows, {row[1]} devices")
        
        return Output(
            value=row[0],
            metadata={
                "row_count": MetadataValue.int(row[0]),
                "unique_devices": MetadataValue.int(row[1]),
                "date_range": MetadataValue.text(f"{row[2]} to {row[3]}"),
            }
        )
    
    return Output(value=0)


# ============================================
# CLICKHOUSE MAINTENANCE ASSETS
# ============================================

@asset(
    group_name="clickhouse_maintenance",
    description="Optimize ClickHouse tables for better performance",
    compute_kind="clickhouse",
)
def optimize_tables(context: AssetExecutionContext):
    """
    Run OPTIMIZE on ClickHouse tables to merge parts.
    Should run during low-traffic periods.
    """
    clickhouse = context.resources.clickhouse
    
    tables = ['events', 'events_1min', 'events_hourly', 'device_daily_summary']
    results = {}
    
    for table in tables:
        try:
            # Run OPTIMIZE FINAL to merge all parts
            clickhouse.execute_command(f"OPTIMIZE TABLE telemetry.{table} FINAL")
            results[table] = "optimized"
            context.log.info(f"Optimized table: telemetry.{table}")
        except Exception as e:
            results[table] = f"error: {str(e)}"
            context.log.warning(f"Failed to optimize {table}: {e}")
    
    return Output(
        value=results,
        metadata={
            "tables_processed": MetadataValue.int(len(tables)),
            "results": MetadataValue.json(results),
        }
    )


@asset(
    group_name="clickhouse_maintenance",
    description="Check and report table sizes",
    compute_kind="clickhouse",
)
def table_sizes(context: AssetExecutionContext):
    """
    Report ClickHouse table sizes for monitoring.
    """
    clickhouse = context.resources.clickhouse
    
    query = """
    SELECT 
        table,
        formatReadableSize(sum(bytes_on_disk)) as size,
        sum(rows) as rows,
        count() as parts
    FROM system.parts
    WHERE database = 'telemetry' AND active = 1
    GROUP BY table
    ORDER BY sum(bytes_on_disk) DESC
    """
    
    result = clickhouse.execute(query)
    
    table_info = [
        {
            'table': row[0],
            'size': row[1],
            'rows': row[2],
            'parts': row[3]
        }
        for row in result.result_rows
    ]
    
    context.log.info(f"Table sizes: {table_info}")
    
    return Output(
        value=table_info,
        metadata={
            "tables": MetadataValue.json(table_info),
        }
    )


@asset(
    group_name="clickhouse_maintenance",
    description="Clean up old partitions based on TTL",
    compute_kind="clickhouse",
)
def partition_cleanup(context: AssetExecutionContext):
    """
    Force TTL cleanup and drop old partitions.
    """
    clickhouse = context.resources.clickhouse
    
    # Force TTL merge
    try:
        clickhouse.execute_command(
            "ALTER TABLE telemetry.events MATERIALIZE TTL"
        )
        context.log.info("TTL materialization triggered")
    except Exception as e:
        context.log.warning(f"TTL materialization failed: {e}")
    
    # Get partition info
    query = """
    SELECT 
        partition,
        formatReadableSize(sum(bytes_on_disk)) as size,
        sum(rows) as rows,
        min(min_time) as min_time,
        max(max_time) as max_time
    FROM system.parts
    WHERE database = 'telemetry' AND table = 'events' AND active = 1
    GROUP BY partition
    ORDER BY partition
    """
    
    result = clickhouse.execute(query)
    partitions = [
        {
            'partition': row[0],
            'size': row[1],
            'rows': row[2],
            'time_range': f"{row[3]} to {row[4]}"
        }
        for row in result.result_rows
    ]
    
    return Output(
        value=partitions,
        metadata={
            "partition_count": MetadataValue.int(len(partitions)),
            "partitions": MetadataValue.json(partitions),
        }
    )


# ============================================
# DATA QUALITY ASSETS
# ============================================

@asset(
    group_name="data_quality",
    description="Data quality metrics and anomaly detection",
    compute_kind="python",
)
def data_quality_metrics(context: AssetExecutionContext):
    """
    Calculate data quality metrics for monitoring.
    """
    clickhouse = context.resources.clickhouse
    
    query = """
    SELECT 
        count() as total_events,
        countIf(temperature IS NULL) as null_temp,
        countIf(pressure IS NULL) as null_pressure,
        countIf(temperature < -50 OR temperature > 100) as temp_outliers,
        countIf(pressure < 50 OR pressure > 200) as pressure_outliers,
        uniq(device_id) as unique_devices,
        min(timestamp) as earliest,
        max(timestamp) as latest
    FROM events
    WHERE timestamp >= now() - INTERVAL 1 HOUR
    """
    
    result = clickhouse.execute(query)
    
    if result.result_rows:
        row = result.result_rows[0]
        total = max(row[0], 1)
        
        metrics = {
            'total_events': row[0],
            'null_temperature_pct': round((row[1] / total) * 100, 2),
            'null_pressure_pct': round((row[2] / total) * 100, 2),
            'temp_outlier_pct': round((row[3] / total) * 100, 2),
            'pressure_outlier_pct': round((row[4] / total) * 100, 2),
            'unique_devices': row[5],
            'data_completeness': round(((total - row[1] - row[2]) / (total * 2)) * 100, 2),
            'checked_at': datetime.now().isoformat()
        }
        
        context.log.info(f"Data quality: completeness={metrics['data_completeness']}%")
        
        # Alert on poor data quality
        if metrics['data_completeness'] < 95:
            context.log.warning(f"Data completeness below 95%: {metrics['data_completeness']}%")
        
        return Output(
            value=metrics,
            metadata={
                "total_events": MetadataValue.int(metrics['total_events']),
                "data_completeness": MetadataValue.float(metrics['data_completeness']),
                "temp_outliers": MetadataValue.float(metrics['temp_outlier_pct']),
            }
        )
    
    return Output(value={}, metadata={"status": MetadataValue.text("no_data")})
