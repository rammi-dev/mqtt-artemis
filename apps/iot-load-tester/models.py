"""Pydantic models for IoT Load Testing API."""

from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field, field_validator


class Protocol(str, Enum):
    """Supported protocols."""
    MQTT = "mqtt"
    MQTT_WS = "mqtt-ws"
    AMQP = "amqp"
    HTTP = "http"


class TestType(str, Enum):
    """Available test types."""
    TELEMETRY = "telemetry"
    BURST = "burst"
    CHURN = "churn"
    RETAINED = "retained"
    COMMAND = "command"
    OFFLINE = "offline"
    LWT = "lwt"


class JobStatus(str, Enum):
    """Job execution status."""
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    STOPPED = "stopped"


class BurstConfig(BaseModel):
    """Burst traffic configuration."""
    enabled: bool = False
    multiplier: int = Field(default=10, ge=1, le=100)
    durationSeconds: int = Field(default=30, ge=1, le=300)


class TestConfig(BaseModel):
    """Load test configuration with safety limits."""
    
    # Protocol settings
    protocol: Protocol = Protocol.MQTT
    brokerUrl: str = Field(..., description="Broker URL (mqtt://host:port)")
    useWebSockets: bool = False
    
    # Test type
    testType: TestType = TestType.TELEMETRY
    
    # Device settings
    devices: int = Field(default=10, ge=1, le=100000)
    connectRate: int = Field(default=100, ge=1, le=2000)
    
    # Topic settings
    topicPattern: str = Field(default="devices/{deviceId}/telemetry")
    
    # MQTT settings
    qos: int = Field(default=1, ge=0, le=2)
    retain: bool = False
    cleanSession: bool = True
    
    # Message settings
    messageSizeBytes: int = Field(default=256, ge=1, le=1048576)
    publishRatePerDevice: float = Field(default=1.0, ge=0.1, le=100)
    messageExpirySeconds: Optional[int] = Field(
        default=None, 
        ge=1, 
        le=86400,
        description="MQTT 5.0 message expiry interval in seconds (max 24h)"
    )
    
    # Burst settings
    burst: Optional[BurstConfig] = None
    
    # Runtime
    runtimeSeconds: int = Field(default=60, ge=10, le=3600)
    
    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "title": "Telemetry Test",
                    "description": "Periodic sensor data publishing",
                    "value": {
                        "protocol": "mqtt",
                        "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                        "testType": "telemetry",
                        "devices": 100,
                        "topicPattern": "devices/{deviceId}/telemetry",
                        "qos": 1,
                        "runtimeSeconds": 60
                    }
                },
                {
                    "title": "Burst Traffic Test",
                    "description": "Simulates traffic spike",
                    "value": {
                        "protocol": "mqtt",
                        "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                        "testType": "burst",
                        "devices": 1000,
                        "burst": {"enabled": True, "multiplier": 10, "durationSeconds": 30},
                        "runtimeSeconds": 120
                    }
                },
                {
                    "title": "Connection Churn Test",
                    "description": "Connect/disconnect cycling",
                    "value": {
                        "protocol": "mqtt",
                        "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                        "testType": "churn",
                        "devices": 500,
                        "cleanSession": False,
                        "runtimeSeconds": 120
                    }
                },
                {
                    "title": "Retained Messages Test",
                    "description": "Retained message fan-out",
                    "value": {
                        "protocol": "mqtt",
                        "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                        "testType": "retained",
                        "devices": 100,
                        "retain": True,
                        "runtimeSeconds": 60
                    }
                },
                {
                    "title": "Command & Control Test",
                    "description": "Backend commands, device responses",
                    "value": {
                        "protocol": "mqtt",
                        "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                        "testType": "command",
                        "devices": 50,
                        "qos": 1,
                        "runtimeSeconds": 60
                    }
                },
                {
                    "title": "Offline Device Test",
                    "description": "Persistent session and replay",
                    "value": {
                        "protocol": "mqtt",
                        "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                        "testType": "offline",
                        "devices": 100,
                        "cleanSession": False,
                        "qos": 1,
                        "runtimeSeconds": 120
                    }
                },
                {
                    "title": "LWT Test",
                    "description": "Last Will & Testament on device failure",
                    "value": {
                        "protocol": "mqtt",
                        "brokerUrl": "mqtt://artemis-mqtt-0-svc.edge:1883",
                        "testType": "lwt",
                        "devices": 100,
                        "runtimeSeconds": 60
                    }
                },
                {
                    "title": "AMQP Test",
                    "description": "AMQP 1.0 protocol test",
                    "value": {
                        "protocol": "amqp",
                        "brokerUrl": "amqp://artemis-amqp-0-svc.edge:5672",
                        "devices": 50,
                        "runtimeSeconds": 60
                    }
                }
            ]
        }
    }
    
    @field_validator('brokerUrl')
    @classmethod
    def validate_broker_url(cls, v: str) -> str:
        if not any(v.startswith(p) for p in ['mqtt://', 'mqtts://', 'ws://', 'wss://', 'amqp://', 'amqps://', 'http://', 'https://']):
            raise ValueError('Invalid broker URL scheme')
        return v


class JobInfo(BaseModel):
    """Job information and status."""
    job_id: str
    status: JobStatus
    config: TestConfig
    started_at: Optional[str] = None
    ended_at: Optional[str] = None
    error: Optional[str] = None
    metrics: Optional[dict] = None


class JobCreateResponse(BaseModel):
    """Response when creating a new job."""
    job_id: str
    status: JobStatus
    message: str


class ErrorResponse(BaseModel):
    """Error response."""
    error: str
    detail: Optional[str] = None
