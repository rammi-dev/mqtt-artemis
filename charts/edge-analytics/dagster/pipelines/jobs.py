"""
Dagster Jobs for Edge Analytics

Jobs define specific workflows that can be triggered manually or via schedules.
"""

from dagster import define_asset_job, AssetSelection


# ============================================
# REDIS SYNC JOB
# ============================================

redis_sync_job = define_asset_job(
    name="redis_sync_job",
    description="Sync all dashboard data from ClickHouse to Redis cache",
    selection=AssetSelection.groups("redis_cache"),
    tags={
        "job_type": "sync",
        "target": "redis",
        "frequency": "minute",
    },
)


# ============================================
# CLICKHOUSE MAINTENANCE JOB
# ============================================

clickhouse_maintenance_job = define_asset_job(
    name="clickhouse_maintenance_job",
    description="Run ClickHouse maintenance tasks (optimize, cleanup)",
    selection=AssetSelection.groups("clickhouse_maintenance"),
    tags={
        "job_type": "maintenance",
        "target": "clickhouse",
        "frequency": "daily",
    },
)


# ============================================
# DATA QUALITY JOB
# ============================================

data_quality_job = define_asset_job(
    name="data_quality_job",
    description="Check data quality metrics and detect anomalies",
    selection=AssetSelection.groups("data_quality"),
    tags={
        "job_type": "quality",
        "target": "monitoring",
        "frequency": "hourly",
    },
)


# ============================================
# AGGREGATION JOBS
# ============================================

hourly_aggregation_job = define_asset_job(
    name="hourly_aggregation_job",
    description="Verify and track hourly aggregations",
    selection=AssetSelection.assets("hourly_aggregation"),
    tags={
        "job_type": "aggregation",
        "target": "clickhouse",
        "frequency": "hourly",
    },
)

daily_aggregation_job = define_asset_job(
    name="daily_aggregation_job",
    description="Generate and verify daily device summaries",
    selection=AssetSelection.assets("daily_device_summary"),
    tags={
        "job_type": "aggregation",
        "target": "clickhouse",
        "frequency": "daily",
    },
)
