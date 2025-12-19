"""
Edge Analytics Dagster Pipelines

This module contains all Dagster assets, jobs, and schedules for:
- ClickHouse data management (aggregations, cleanup, optimization)
- Redis cache synchronization
- Data quality monitoring
- Batch ETL operations
"""

from dagster import Definitions, load_assets_from_modules

from . import assets, jobs, schedules, sensors, resources

# Load all assets from the assets module
all_assets = load_assets_from_modules([assets])

# Create the Dagster definitions
defs = Definitions(
    assets=all_assets,
    jobs=[
        jobs.redis_sync_job,
        jobs.clickhouse_maintenance_job,
        jobs.data_quality_job,
        jobs.hourly_aggregation_job,
        jobs.daily_aggregation_job,
    ],
    schedules=[
        schedules.redis_sync_schedule,
        schedules.hourly_aggregation_schedule,
        schedules.daily_aggregation_schedule,
        schedules.clickhouse_maintenance_schedule,
        schedules.data_quality_schedule,
    ],
    sensors=[
        sensors.high_volume_sensor,
        sensors.data_freshness_sensor,
    ],
    resources={
        "clickhouse": resources.clickhouse_resource,
        "redis": resources.redis_resource,
    },
)
