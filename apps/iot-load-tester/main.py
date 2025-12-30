"""FastAPI application for IoT Load Testing."""

from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional

from models import TestConfig, JobInfo, JobCreateResponse, ErrorResponse, Protocol, TestType, BurstConfig
from job_manager import job_manager
from metrics import get_metrics, get_content_type, VALIDATION_REJECTIONS


@asynccontextmanager
async def lifespan(app: FastAPI):
    """App lifespan handler."""
    yield
    await job_manager.cleanup_expired()


app = FastAPI(
    title="IoT Load Testing Tool",
    description="REST-driven load-testing platform for Apache Artemis focused on IoT protocols",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =============================================================================
# Simplified request models for each test type
# =============================================================================

class TelemetryTestRequest(BaseModel):
    """Telemetry test - periodic sensor data publishing."""
    brokerUrl: str = Field(
        default="mqtt://artemis-mqtt-0-svc.edge:1883",
        description="MQTT broker URL"
    )
    devices: int = Field(default=100, ge=1, le=100000)
    topicPattern: str = Field(default="devices/{deviceId}/telemetry")
    qos: int = Field(default=1, ge=0, le=2)
    publishRatePerDevice: float = Field(default=1.0, ge=0.1, le=100)
    messageSizeBytes: int = Field(default=256, ge=1, le=1048576)
    messageExpirySeconds: Optional[int] = Field(
        default=None, 
        ge=1, 
        le=86400,
        description="MQTT 5.0 message expiry in seconds (how long message stays in broker)"
    )
    runtimeSeconds: int = Field(default=60, ge=10, le=3600)
    
    class Config:
        json_schema_extra = {
            "example": {
                "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                "devices": 100,
                "messageExpirySeconds": 60,
                "runtimeSeconds": 120
            }
        }


class BurstTestRequest(BaseModel):
    """Burst test - simulates coordinated traffic spikes."""
    brokerUrl: str = Field(default="mqtt://artemis-mqtt-0-svc.edge:1883")
    devices: int = Field(default=1000, ge=1, le=100000)
    multiplier: int = Field(default=10, ge=1, le=100, description="Traffic multiplier during burst")
    burstDurationSeconds: int = Field(default=30, ge=1, le=300)
    messageExpirySeconds: Optional[int] = Field(
        default=None, ge=1, le=86400,
        description="MQTT 5.0 message expiry in seconds"
    )
    runtimeSeconds: int = Field(default=120, ge=10, le=3600)
    
    class Config:
        json_schema_extra = {
            "example": {
                "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                "devices": 1000,
                "multiplier": 10,
                "messageExpirySeconds": 120,
                "runtimeSeconds": 300
            }
        }


class ChurnTestRequest(BaseModel):
    """Churn test - simulates unstable device connections."""
    brokerUrl: str = Field(default="mqtt://artemis-mqtt-0-svc.edge:1883")
    devices: int = Field(default=500, ge=1, le=100000)
    runtimeSeconds: int = Field(default=120, ge=10, le=3600)
    
    class Config:
        json_schema_extra = {
            "example": {
                "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                "devices": 500,
                "runtimeSeconds": 120
            }
        }


class RetainedTestRequest(BaseModel):
    """Retained test - tests retained message fan-out."""
    brokerUrl: str = Field(default="mqtt://artemis-mqtt-0-svc.edge:1883")
    devices: int = Field(default=100, ge=1, le=100000)
    messageExpirySeconds: Optional[int] = Field(
        default=None, ge=1, le=86400,
        description="MQTT 5.0 message expiry in seconds"
    )
    runtimeSeconds: int = Field(default=60, ge=10, le=3600)
    
    class Config:
        json_schema_extra = {
            "example": {
                "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                "devices": 100,
                "messageExpirySeconds": 300,
                "runtimeSeconds": 120
            }
        }


class CommandTestRequest(BaseModel):
    """Command test - backend sends commands, devices respond."""
    brokerUrl: str = Field(default="mqtt://artemis-mqtt-0-svc.edge:1883")
    devices: int = Field(default=50, ge=1, le=100000)
    qos: int = Field(default=1, ge=0, le=2)
    runtimeSeconds: int = Field(default=60, ge=10, le=3600)
    
    class Config:
        json_schema_extra = {
            "example": {
                "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                "devices": 50,
                "qos": 1,
                "runtimeSeconds": 60
            }
        }


class OfflineTestRequest(BaseModel):
    """Offline test - tests persistent sessions and message replay."""
    brokerUrl: str = Field(default="mqtt://artemis-mqtt-0-svc.edge:1883")
    devices: int = Field(default=100, ge=1, le=100000)
    qos: int = Field(default=1, ge=0, le=2)
    runtimeSeconds: int = Field(default=120, ge=10, le=3600)
    
    class Config:
        json_schema_extra = {
            "example": {
                "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                "devices": 100,
                "qos": 1,
                "runtimeSeconds": 120
            }
        }


class LwtTestRequest(BaseModel):
    """LWT test - tests Last Will & Testament on device failure."""
    brokerUrl: str = Field(default="mqtt://artemis-mqtt-0-svc.edge:1883")
    devices: int = Field(default=100, ge=1, le=100000)
    runtimeSeconds: int = Field(default=60, ge=10, le=3600)
    
    class Config:
        json_schema_extra = {
            "example": {
                "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                "devices": 100,
                "runtimeSeconds": 60
            }
        }


class AmqpTestRequest(BaseModel):
    """AMQP test - tests AMQP 1.0 protocol."""
    brokerUrl: str = Field(default="amqp://artemis-amqp-0-svc.edge:5672")
    devices: int = Field(default=50, ge=1, le=100000)
    runtimeSeconds: int = Field(default=60, ge=10, le=3600)
    
    class Config:
        json_schema_extra = {
            "example": {
                "brokerUrl": "amqp://artemis-amqp-0-svc.edge:5672",
                "devices": 50,
                "runtimeSeconds": 60
            }
        }


# =============================================================================
# Helper to convert requests to TestConfig
# =============================================================================

async def start_test(config: TestConfig) -> JobCreateResponse:
    """Common logic to start a test."""
    try:
        job = await job_manager.create_job(config)
        return JobCreateResponse(
            job_id=job.job_id,
            status=job.status,
            message=f"Test started with {config.devices} devices"
        )
    except ValueError as e:
        VALIDATION_REJECTIONS.labels(reason="limit_exceeded").inc()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =============================================================================
# Endpoints
# =============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "running_jobs": job_manager.running_count}


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint."""
    return Response(content=get_metrics(), media_type=get_content_type())


# --- Test Type Endpoints ---

@app.post("/tests/telemetry", response_model=JobCreateResponse, tags=["Test Types"])
async def create_telemetry_test(request: TelemetryTestRequest):
    """Start a **Telemetry** test.
    
    **How it works:**
    - Each simulated device connects to the MQTT broker
    - Devices publish periodic sensor data (temperature, humidity, pressure) to their topic
    - Messages are sent at the configured `publishRatePerDevice` (default: 1 msg/sec)
    - Useful for testing sustained IoT traffic patterns
    
    **Metrics to watch:**
    - Publish latency
    - Message throughput
    - Broker CPU/memory under load
    """
    config = TestConfig(
        protocol=Protocol.MQTT,
        brokerUrl=request.brokerUrl,
        testType=TestType.TELEMETRY,
        devices=request.devices,
        topicPattern=request.topicPattern,
        qos=request.qos,
        publishRatePerDevice=request.publishRatePerDevice,
        messageSizeBytes=request.messageSizeBytes,
        runtimeSeconds=request.runtimeSeconds
    )
    return await start_test(config)


@app.post("/tests/burst", response_model=JobCreateResponse, tags=["Test Types"])
async def create_burst_test(request: BurstTestRequest):
    """Start a **Burst Traffic** test.
    
    **How it works:**
    - All devices connect and begin normal publishing
    - Suddenly, traffic multiplies by the `multiplier` factor (e.g., 10x)
    - Burst lasts for `burstDurationSeconds` then returns to normal
    - Simulates coordinated events (e.g., all devices reporting at midnight)
    
    **Use cases:**
    - Test broker behavior under traffic spikes
    - Validate auto-scaling triggers
    - Stress test message queuing
    """
    config = TestConfig(
        protocol=Protocol.MQTT,
        brokerUrl=request.brokerUrl,
        testType=TestType.BURST,
        devices=request.devices,
        burst=BurstConfig(enabled=True, multiplier=request.multiplier, durationSeconds=request.burstDurationSeconds),
        runtimeSeconds=request.runtimeSeconds
    )
    return await start_test(config)


@app.post("/tests/churn", response_model=JobCreateResponse, tags=["Test Types"])
async def create_churn_test(request: ChurnTestRequest):
    """Start a **Connection Churn** test.
    
    **How it works:**
    - Devices repeatedly connect, publish a few messages, then disconnect
    - Random delays between reconnection attempts (0.5-2 seconds)
    - Simulates unstable network conditions or battery-saving devices
    - Uses `cleanSession=false` to test session persistence
    
    **Use cases:**
    - Test broker connection handling under high churn
    - Validate session state management
    - Stress test connection authentication
    """
    config = TestConfig(
        protocol=Protocol.MQTT,
        brokerUrl=request.brokerUrl,
        testType=TestType.CHURN,
        devices=request.devices,
        cleanSession=False,
        runtimeSeconds=request.runtimeSeconds
    )
    return await start_test(config)


@app.post("/tests/retained", response_model=JobCreateResponse, tags=["Test Types"])
async def create_retained_test(request: RetainedTestRequest):
    """Start a **Retained Messages** test.
    
    **How it works:**
    - Each device publishes retained messages to status topics
    - Retained messages stay in broker until replaced/deleted
    - New subscribers immediately receive the last retained message
    - Tests broker's retained message storage and fan-out
    
    **Use cases:**
    - Test retained message memory usage
    - Validate "last known good" value delivery
    - Stress test subscriber fan-out with retained messages
    """
    config = TestConfig(
        protocol=Protocol.MQTT,
        brokerUrl=request.brokerUrl,
        testType=TestType.RETAINED,
        devices=request.devices,
        retain=True,
        runtimeSeconds=request.runtimeSeconds
    )
    return await start_test(config)


@app.post("/tests/command", response_model=JobCreateResponse, tags=["Test Types"])
async def create_command_test(request: CommandTestRequest):
    """Start a **Command & Control** test.
    
    **How it works:**
    - Each device subscribes to its command topic
    - Device listens for incoming commands from backend
    - When command received, device publishes response to response topic
    - Tests bidirectional communication patterns
    
    **Use cases:**
    - Test command delivery latency
    - Validate request-response patterns
    - Stress test subscribe/publish round-trips
    """
    config = TestConfig(
        protocol=Protocol.MQTT,
        brokerUrl=request.brokerUrl,
        testType=TestType.COMMAND,
        devices=request.devices,
        qos=request.qos,
        runtimeSeconds=request.runtimeSeconds
    )
    return await start_test(config)


@app.post("/tests/offline", response_model=JobCreateResponse, tags=["Test Types"])
async def create_offline_test(request: OfflineTestRequest):
    """Start an **Offline Device Backlog** test.
    
    **How it works:**
    - Device connects with `cleanSession=false` (persistent session)
    - Device publishes message, then disconnects (simulating network loss)
    - Device stays offline for 1-5 seconds
    - Device reconnects - broker should replay queued messages
    
    **Use cases:**
    - Test persistent session storage
    - Validate message queuing during offline periods
    - Stress test session state recovery
    """
    config = TestConfig(
        protocol=Protocol.MQTT,
        brokerUrl=request.brokerUrl,
        testType=TestType.OFFLINE,
        devices=request.devices,
        cleanSession=False,
        qos=request.qos,
        runtimeSeconds=request.runtimeSeconds
    )
    return await start_test(config)


@app.post("/tests/lwt", response_model=JobCreateResponse, tags=["Test Types"])
async def create_lwt_test(request: LwtTestRequest):
    """Start a **Last Will & Testament (LWT)** test.
    
    **How it works:**
    - Each device sets an LWT message on connect (e.g., `{"online": false}`)
    - If device disconnects unexpectedly, broker publishes LWT to status topic
    - Other subscribers are notified of device failure
    - Tests broker's LWT handling under load
    
    **Use cases:**
    - Test device failure detection
    - Validate LWT message delivery timing
    - Stress test concurrent LWT triggers
    """
    config = TestConfig(
        protocol=Protocol.MQTT,
        brokerUrl=request.brokerUrl,
        testType=TestType.LWT,
        devices=request.devices,
        runtimeSeconds=request.runtimeSeconds
    )
    return await start_test(config)


@app.post("/tests/amqp", response_model=JobCreateResponse, tags=["Test Types"])
async def create_amqp_test(request: AmqpTestRequest):
    """Start an **AMQP 1.0** test.
    
    **How it works:**
    - Devices connect using AMQP 1.0 protocol (port 5672)
    - Messages sent as AMQP messages to queues/topics
    - Tests Artemis's native AMQP protocol support
    - Can set per-message TTL using AMQP message properties
    
    **Use cases:**
    - Compare AMQP vs MQTT performance
    - Test AMQP-specific features (transactions, selectors)
    - Validate multi-protocol broker behavior
    """
    config = TestConfig(
        protocol=Protocol.AMQP,
        brokerUrl=request.brokerUrl,
        testType=TestType.TELEMETRY,
        devices=request.devices,
        runtimeSeconds=request.runtimeSeconds
    )
    return await start_test(config)


# --- Generic Endpoints ---

@app.post("/tests", response_model=JobCreateResponse, responses={400: {"model": ErrorResponse}}, tags=["Generic"])
async def create_test(config: TestConfig):
    """Start a custom load test with full configuration options."""
    return await start_test(config)


@app.get("/tests", response_model=list[JobInfo], tags=["Jobs"])
async def list_tests():
    """List all load tests."""
    return await job_manager.list_jobs()


@app.get("/tests/{job_id}", response_model=JobInfo, responses={404: {"model": ErrorResponse}}, tags=["Jobs"])
async def get_test(job_id: str):
    """Get status of a load test."""
    job = await job_manager.get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
    return job.to_info()


@app.delete("/tests/{job_id}", responses={404: {"model": ErrorResponse}}, tags=["Jobs"])
async def stop_test(job_id: str):
    """Stop a running load test."""
    stopped = await job_manager.stop_job(job_id)
    if not stopped:
        job = await job_manager.get_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
        return {"message": f"Job {job_id} is not running", "status": job.status.value}
    return {"message": f"Job {job_id} stopped"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8090)
