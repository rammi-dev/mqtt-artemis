"""
Dagster Sensors for Edge Analytics

Sensors react to external events and trigger jobs based on conditions.
"""

from dagster import sensor, RunRequest, SensorEvaluationContext, SkipReason
from datetime import datetime, timedelta


@sensor(
    job_name="redis_sync_job",
    minimum_interval_seconds=30,
    description="Trigger Redis sync when high data volume detected",
)
def high_volume_sensor(context: SensorEvaluationContext):
    """
    Sensor that triggers additional Redis syncs during high-volume periods.
    Monitors ClickHouse insert rate and triggers sync if threshold exceeded.
    """
    clickhouse = context.resources.clickhouse
    
    # Check events in last minute
    query = """
    SELECT count() as events
    FROM events
    WHERE timestamp >= now() - INTERVAL 1 MINUTE
    """
    
    try:
        result = clickhouse.execute(query)
        event_count = result.result_rows[0][0] if result.result_rows else 0
        
        # Threshold: more than 1000 events/minute triggers extra sync
        if event_count > 1000:
            context.log.info(f"High volume detected: {event_count} events/min")
            return RunRequest(
                run_key=f"high_volume_{datetime.now().strftime('%Y%m%d%H%M')}",
                tags={
                    "triggered_by": "high_volume_sensor",
                    "event_count": str(event_count),
                },
            )
        
        return SkipReason(f"Normal volume: {event_count} events/min (threshold: 1000)")
    
    except Exception as e:
        return SkipReason(f"Error checking volume: {e}")


@sensor(
    job_name="data_quality_job",
    minimum_interval_seconds=300,  # 5 minutes
    description="Trigger data quality check if data freshness drops",
)
def data_freshness_sensor(context: SensorEvaluationContext):
    """
    Sensor that monitors data freshness and triggers quality check
    if no new data received for too long.
    """
    clickhouse = context.resources.clickhouse
    
    # Check most recent event timestamp
    query = """
    SELECT max(timestamp) as latest
    FROM events
    """
    
    try:
        result = clickhouse.execute(query)
        
        if result.result_rows and result.result_rows[0][0]:
            latest = result.result_rows[0][0]
            age = datetime.now() - latest
            
            # Alert if no data for more than 5 minutes
            if age > timedelta(minutes=5):
                context.log.warning(f"Data freshness alert: last event {age} ago")
                return RunRequest(
                    run_key=f"freshness_alert_{datetime.now().strftime('%Y%m%d%H%M')}",
                    tags={
                        "triggered_by": "data_freshness_sensor",
                        "data_age_seconds": str(int(age.total_seconds())),
                    },
                )
            
            return SkipReason(f"Data is fresh: last event {age} ago")
        
        return SkipReason("No data in events table")
    
    except Exception as e:
        return SkipReason(f"Error checking freshness: {e}")
