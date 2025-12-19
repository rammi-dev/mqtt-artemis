-- Edge Analytics - Optimized ClickHouse Schema
-- Apply this to improve storage efficiency and query performance

-- ============================================
-- 1. OPTIMIZED EVENTS TABLE
-- ============================================

CREATE DATABASE IF NOT EXISTS telemetry;

-- Drop existing table if recreating (CAUTION: data loss)
-- DROP TABLE IF EXISTS telemetry.events;

CREATE TABLE IF NOT EXISTS telemetry.events
(
    -- Timestamp with millisecond precision, DoubleDelta compression
    timestamp DateTime64(3) CODEC(DoubleDelta, LZ4),
    
    -- Device ID - LowCardinality for repeated string values
    device_id LowCardinality(String),
    
    -- Metrics - Float32 is sufficient, Gorilla compression for time-series
    temperature Float32 CODEC(Gorilla, LZ4),
    pressure Float32 CODEC(Gorilla, LZ4),
    
    -- Status - only 'OK' or 'WARN', LowCardinality is perfect
    status LowCardinality(String),
    
    -- Message ID - monotonic, Delta compression works well
    msg_id UInt64 CODEC(Delta, LZ4)
)
ENGINE = MergeTree()
-- Partition by month for easier data management
PARTITION BY toYYYYMM(timestamp)
-- Order optimized for device-centric queries
ORDER BY (device_id, timestamp)
-- Auto-expire data after 90 days
TTL timestamp + INTERVAL 90 DAY
SETTINGS 
    index_granularity = 8192,
    min_bytes_for_wide_part = 0;

-- ============================================
-- 2. MATERIALIZED VIEW: 1-MINUTE AGGREGATIONS
-- ============================================
-- Pre-compute per-minute stats for faster dashboard queries

CREATE MATERIALIZED VIEW IF NOT EXISTS telemetry.events_1min
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMMDD(minute)
ORDER BY (device_id, minute)
TTL minute + INTERVAL 7 DAY  -- Keep 7 days of minute data
AS SELECT
    toStartOfMinute(timestamp) AS minute,
    device_id,
    count() AS event_count,
    sum(temperature) AS sum_temperature,
    min(temperature) AS min_temperature,
    max(temperature) AS max_temperature,
    sum(pressure) AS sum_pressure,
    min(pressure) AS min_pressure,
    max(pressure) AS max_pressure,
    countIf(status = 'OK') AS ok_count,
    countIf(status = 'WARN') AS warn_count
FROM telemetry.events
GROUP BY device_id, toStartOfMinute(timestamp);

-- ============================================
-- 3. MATERIALIZED VIEW: HOURLY AGGREGATIONS
-- ============================================
-- For 24-hour dashboards and historical analysis

CREATE MATERIALIZED VIEW IF NOT EXISTS telemetry.events_hourly
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(hour)
ORDER BY (device_id, hour)
TTL hour + INTERVAL 365 DAY  -- Keep 1 year of hourly data
AS SELECT
    toStartOfHour(timestamp) AS hour,
    device_id,
    count() AS event_count,
    sum(temperature) AS sum_temperature,
    min(temperature) AS min_temperature,
    max(temperature) AS max_temperature,
    sum(pressure) AS sum_pressure,
    min(pressure) AS min_pressure,
    max(pressure) AS max_pressure,
    countIf(status = 'OK') AS ok_count,
    countIf(status = 'WARN') AS warn_count
FROM telemetry.events
GROUP BY device_id, toStartOfHour(timestamp);

-- ============================================
-- 4. MATERIALIZED VIEW: DAILY DEVICE SUMMARY
-- ============================================
-- For device health reports and trends

CREATE MATERIALIZED VIEW IF NOT EXISTS telemetry.device_daily_summary
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (device_id, date)
TTL date + INTERVAL 2 YEAR  -- Keep 2 years of daily data
AS SELECT
    toDate(timestamp) AS date,
    device_id,
    count() AS total_events,
    countIf(status = 'WARN') AS warnings,
    sum(temperature) AS sum_temperature,
    sum(pressure) AS sum_pressure
FROM telemetry.events
GROUP BY device_id, toDate(timestamp);

-- ============================================
-- 5. OPTIMIZED QUERIES FOR DASHBOARDS
-- ============================================

-- Query 1: Real-time device stats using materialized view
-- SELECT 
--     device_id,
--     sum(event_count) as messages,
--     sum(sum_temperature) / sum(event_count) as avg_temp,
--     min(min_temperature) as min_temp,
--     max(max_temperature) as max_temp,
--     sum(warn_count) as warnings
-- FROM telemetry.events_1min
-- WHERE minute >= now() - INTERVAL 5 MINUTE
-- GROUP BY device_id;

-- Query 2: Hourly trends using materialized view
-- SELECT 
--     hour,
--     sum(event_count) as events,
--     sum(sum_temperature) / sum(event_count) as avg_temp
-- FROM telemetry.events_hourly
-- WHERE hour >= now() - INTERVAL 24 HOUR
-- GROUP BY hour
-- ORDER BY hour;

-- ============================================
-- 6. SYSTEM SETTINGS RECOMMENDATIONS
-- ============================================
-- Add to ClickHouse server config:
--
-- <max_memory_usage>4000000000</max_memory_usage>  -- 4GB per query
-- <max_threads>4</max_threads>
-- <background_pool_size>8</background_pool_size>
-- <merge_tree>
--     <max_bytes_to_merge_at_max_space_in_pool>161061273600</max_bytes_to_merge_at_max_space_in_pool>
-- </merge_tree>
