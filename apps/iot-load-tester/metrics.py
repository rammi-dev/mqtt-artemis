"""Prometheus metrics for IoT Load Testing."""

from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST

# Job metrics
JOBS_STARTED = Counter('loadtest_jobs_started_total', 'Total jobs started', ['protocol', 'test_type'])
JOBS_RUNNING = Gauge('loadtest_jobs_running', 'Currently running jobs')
JOBS_COMPLETED = Counter('loadtest_jobs_completed_total', 'Total jobs completed', ['protocol', 'status'])
JOBS_FAILED = Counter('loadtest_jobs_failed_total', 'Total jobs failed', ['protocol', 'reason'])

# Validation metrics
VALIDATION_REJECTIONS = Counter('loadtest_validation_rejections_total', 'Validation rejections', ['reason'])

# Job duration
JOB_DURATION = Histogram(
    'loadtest_job_duration_seconds',
    'Job duration in seconds',
    ['protocol', 'test_type'],
    buckets=[10, 30, 60, 120, 300, 600, 1800, 3600]
)

# MQTT metrics
MQTT_CONNECTS = Counter('loadtest_mqtt_connects_total', 'MQTT connect attempts', ['status'])
MQTT_DISCONNECTS = Counter('loadtest_mqtt_disconnects_total', 'MQTT disconnects', ['reason'])
MQTT_PUBLISHES = Counter('loadtest_mqtt_publishes_total', 'MQTT messages published', ['qos'])
MQTT_PUBLISH_LATENCY = Histogram(
    'loadtest_mqtt_publish_latency_seconds',
    'MQTT publish latency',
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]
)

# AMQP metrics
AMQP_CONNECTS = Counter('loadtest_amqp_connects_total', 'AMQP connect attempts', ['status'])
AMQP_SENDS = Counter('loadtest_amqp_sends_total', 'AMQP messages sent')
AMQP_SEND_LATENCY = Histogram(
    'loadtest_amqp_send_latency_seconds',
    'AMQP send latency',
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]
)

# HTTP metrics
HTTP_REQUESTS = Counter('loadtest_http_requests_total', 'HTTP requests', ['method', 'status'])
HTTP_LATENCY = Histogram(
    'loadtest_http_request_latency_seconds',
    'HTTP request latency',
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)


def get_metrics() -> bytes:
    """Generate Prometheus metrics in text format."""
    return generate_latest()


def get_content_type() -> str:
    """Get Prometheus content type."""
    return CONTENT_TYPE_LATEST
