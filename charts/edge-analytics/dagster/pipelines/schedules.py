"""
Dagster Schedules for Edge Analytics

Schedules define when jobs run automatically.
"""

from dagster import ScheduleDefinition, DefaultScheduleStatus


# ============================================
# REDIS SYNC SCHEDULE (Every Minute)
# ============================================

redis_sync_schedule = ScheduleDefinition(
    name="redis_sync_schedule",
    job_name="redis_sync_job",
    cron_schedule="* * * * *",  # Every minute
    default_status=DefaultScheduleStatus.RUNNING,
    description="Sync dashboard data from ClickHouse to Redis every minute",
    tags={
        "schedule_type": "high_frequency",
    },
)


# ============================================
# AGGREGATION SCHEDULES
# ============================================

hourly_aggregation_schedule = ScheduleDefinition(
    name="hourly_aggregation_schedule",
    job_name="hourly_aggregation_job",
    cron_schedule="5 * * * *",  # 5 minutes past every hour
    default_status=DefaultScheduleStatus.RUNNING,
    description="Verify hourly aggregations at 5 minutes past each hour",
    tags={
        "schedule_type": "hourly",
    },
)

daily_aggregation_schedule = ScheduleDefinition(
    name="daily_aggregation_schedule",
    job_name="daily_aggregation_job",
    cron_schedule="0 1 * * *",  # 1:00 AM daily
    default_status=DefaultScheduleStatus.RUNNING,
    description="Generate daily device summaries at 1 AM",
    tags={
        "schedule_type": "daily",
    },
)


# ============================================
# MAINTENANCE SCHEDULES
# ============================================

clickhouse_maintenance_schedule = ScheduleDefinition(
    name="clickhouse_maintenance_schedule",
    job_name="clickhouse_maintenance_job",
    cron_schedule="0 3 * * *",  # 3:00 AM daily (low traffic period)
    default_status=DefaultScheduleStatus.RUNNING,
    description="Run ClickHouse maintenance at 3 AM daily",
    tags={
        "schedule_type": "maintenance",
    },
)


# ============================================
# DATA QUALITY SCHEDULES
# ============================================

data_quality_schedule = ScheduleDefinition(
    name="data_quality_schedule",
    job_name="data_quality_job",
    cron_schedule="0 * * * *",  # Every hour on the hour
    default_status=DefaultScheduleStatus.RUNNING,
    description="Check data quality metrics every hour",
    tags={
        "schedule_type": "monitoring",
    },
)
