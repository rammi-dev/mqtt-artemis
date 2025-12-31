"""Locust load file for IoT device simulation."""

import os
import time
import json
import random
import string
from locust import User, task, events, between

# Import protocol-specific clients
from protocols.mqtt_device import MQTTDevice
from protocols.amqp_device import AMQPDevice
from protocols.http_client import HTTPClient


def get_env(key: str, default: str = "") -> str:
    """Get environment variable."""
    return os.environ.get(key, default)


def get_env_bool(key: str, default: bool = False) -> bool:
    """Get boolean environment variable."""
    return get_env(key, str(default)).lower() == "true"


def get_env_int(key: str, default: int = 0) -> int:
    """Get integer environment variable."""
    return int(get_env(key, str(default)))


def get_env_float(key: str, default: float = 0.0) -> float:
    """Get float environment variable."""
    return float(get_env(key, str(default)))


class IoTDeviceUser(User):
    """Simulates an IoT device."""
    
    # No wait time - event driven
    wait_time = between(0, 0)
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        # Configuration from environment
        self.protocol = get_env("LOADTEST_PROTOCOL", "mqtt")
        self.broker_url = get_env("LOADTEST_BROKER_URL", "mqtt://localhost:1883")
        self.test_type = get_env("LOADTEST_TEST_TYPE", "telemetry")
        self.topic_pattern = get_env("LOADTEST_TOPIC_PATTERN", "devices/{deviceId}/telemetry")
        self.qos = get_env_int("LOADTEST_QOS", 1)
        self.retain = get_env_bool("LOADTEST_RETAIN", False)
        self.clean_session = get_env_bool("LOADTEST_CLEAN_SESSION", True)
        self.message_size = get_env_int("LOADTEST_MESSAGE_SIZE", 256)
        self.publish_rate = get_env_float("LOADTEST_PUBLISH_RATE", 1.0)
        self.use_websockets = get_env_bool("LOADTEST_USE_WEBSOCKETS", False)
        self.message_expiry = get_env_int("LOADTEST_MESSAGE_EXPIRY", 0) or None
        
        # Device ID
        self.device_id = f"device-{self.environment.runner.user_count:05d}-{''.join(random.choices(string.ascii_lowercase, k=4))}"
        
        # Protocol client
        self.client = None
        self.connected = False
        self.last_publish = 0
        self.publish_interval = 1.0 / self.publish_rate if self.publish_rate > 0 else 1.0
    
    def on_start(self):
        """Called when user starts - connect to broker."""
        try:
            if self.protocol == "mqtt" or self.protocol == "mqtt-ws":
                self.client = MQTTDevice(
                    broker_url=self.broker_url,
                    device_id=self.device_id,
                    use_websockets=self.use_websockets or self.protocol == "mqtt-ws",
                    clean_session=self.clean_session,
                    qos=self.qos,
                    message_expiry_seconds=self.message_expiry
                )
            elif self.protocol == "amqp":
                self.client = AMQPDevice(
                    broker_url=self.broker_url,
                    device_id=self.device_id
                )
            elif self.protocol == "http":
                self.client = HTTPClient(
                    base_url=self.broker_url,
                    device_id=self.device_id
                )
            else:
                raise ValueError(f"Unknown protocol: {self.protocol}")
            
            start = time.time()
            self.client.connect()
            duration = time.time() - start
            
            events.request.fire(
                request_type=self.protocol.upper(),
                name="connect",
                response_time=duration * 1000,
                response_length=0,
                exception=None
            )
            self.connected = True
            
        except Exception as e:
            events.request.fire(
                request_type=self.protocol.upper(),
                name="connect",
                response_time=0,
                response_length=0,
                exception=e
            )
    
    def on_stop(self):
        """Called when user stops - disconnect."""
        if self.client and self.connected:
            try:
                self.client.disconnect()
            except Exception:
                pass
    
    @task
    def run_test(self):
        """Main test task - runs based on test type."""
        if not self.connected or not self.client:
            # Try to reconnect if client exists but disconnected
            if self.client and not self.connected:
                try:
                    self.client.connect()
                    self.connected = True
                    # Log successful reconnection
                    events.request.fire(
                        request_type=self.protocol.upper(),
                        name="reconnect_success",
                        response_time=0,
                        response_length=0,
                        exception=None
                    )
                except Exception as e:
                    # Failed to reconnect, back off slightly
                    time.sleep(1.0)
                    events.request.fire(
                        request_type=self.protocol.upper(),
                        name="reconnect_fail",
                        response_time=0,
                        response_length=0,
                        exception=e
                    )
            return
        
        # Rate limiting
        now = time.time()
        time_since_last = now - self.last_publish
        if time_since_last < self.publish_interval:
            sleep_time = self.publish_interval - time_since_last
            if sleep_time > 0:
                time.sleep(sleep_time)
        
        try:
            if self.test_type == "telemetry":
                self._telemetry_test()
            elif self.test_type == "burst":
                self._burst_test()
            elif self.test_type == "churn":
                self._churn_test()
            elif self.test_type == "retained":
                self._retained_test()
            elif self.test_type == "command":
                self._command_test()
            elif self.test_type == "offline":
                self._offline_test()
            elif self.test_type == "lwt":
                self._lwt_test()
            else:
                self._telemetry_test()
                
        except Exception as e:
            events.request.fire(
                request_type=self.protocol.upper(),
                name=self.test_type,
                response_time=0,
                response_length=0,
                exception=e
            )
    
    def _generate_payload(self) -> bytes:
        """Generate test payload with realistic sensor trends."""
        # Use device ID hash as seed for reproducible but varied trends
        device_seed = hash(self.device_id) % 10000
        
        # Time-based trend (changes gradually over execution)
        elapsed = time.time() - getattr(self, '_start_time', time.time())
        if not hasattr(self, '_start_time'):
            self._start_time = time.time()
        
        # Seed random for this device
        random.seed(device_seed + int(elapsed))
        
        # Temperature: baseline + slow trend + small noise
        temp_baseline = 20 + (device_seed % 20) - 10  # 10-30°C baseline per device
        temp_trend = 5 * (elapsed / 3600)  # +5°C per hour trend
        temp_noise = random.uniform(-0.5, 0.5)
        temperature = round(temp_baseline + temp_trend + temp_noise, 2)
        
        # Humidity: baseline + cyclic pattern + noise
        humidity_baseline = 50 + (device_seed % 30) - 15  # 35-65% baseline
        humidity_cycle = 10 * (1 + (elapsed % 300) / 300)  # 5-min cycle
        humidity_noise = random.uniform(-2, 2)
        humidity = round(max(0, min(100, humidity_baseline + humidity_cycle + humidity_noise)), 2)
        
        # Pressure: stable with small variations
        pressure_baseline = 1013 + (device_seed % 20) - 10  # 1003-1023 hPa
        pressure_noise = random.uniform(-0.5, 0.5)
        pressure = round(pressure_baseline + pressure_noise, 2)
        
        # Reset random to system state
        random.seed()
        
        data = {
            "deviceId": self.device_id,
            "timestamp": int(time.time() * 1000),
            "temperature": temperature,
            "humidity": humidity,
            "pressure": pressure,
            "padding": "x" * max(0, self.message_size - 200)
        }
        return json.dumps(data).encode()
    
    def _telemetry_test(self):
        """Periodic telemetry publishing."""
        topic = self.topic_pattern.replace("{deviceId}", self.device_id)
        payload = self._generate_payload()
        
        start = time.time()
        self.client.publish(topic, payload, qos=self.qos, retain=self.retain)
        duration = time.time() - start
        
        events.request.fire(
            request_type=self.protocol.upper(),
            name="publish",
            response_time=duration * 1000,
            response_length=len(payload),
            exception=None
        )
        self.last_publish = time.time()
    
    def _burst_test(self):
        """Burst traffic - publish multiple messages rapidly."""
        topic = self.topic_pattern.replace("{deviceId}", self.device_id)
        burst_count = 10
        
        for _ in range(burst_count):
            payload = self._generate_payload()
            start = time.time()
            self.client.publish(topic, payload, qos=self.qos)
            duration = time.time() - start
            
            events.request.fire(
                request_type=self.protocol.upper(),
                name="publish_burst",
                response_time=duration * 1000,
                response_length=len(payload),
                exception=None
            )
        self.last_publish = time.time()
    
    def _churn_test(self):
        """Connection churn - disconnect and reconnect."""
        # Disconnect
        self.client.disconnect()
        
        # Wait briefly
        time.sleep(random.uniform(0.5, 2.0))
        
        # Reconnect
        start = time.time()
        self.client.connect()
        duration = time.time() - start
        
        events.request.fire(
            request_type=self.protocol.upper(),
            name="reconnect",
            response_time=duration * 1000,
            response_length=0,
            exception=None
        )
    
    def _retained_test(self):
        """Retained message test."""
        topic = f"devices/{self.device_id}/status"
        payload = json.dumps({"online": True, "timestamp": int(time.time() * 1000)}).encode()
        
        start = time.time()
        self.client.publish(topic, payload, qos=1, retain=True)
        duration = time.time() - start
        
        events.request.fire(
            request_type=self.protocol.upper(),
            name="publish_retained",
            response_time=duration * 1000,
            response_length=len(payload),
            exception=None
        )
        self.last_publish = time.time()
    
    def _command_test(self):
        """Command & control - subscribe and respond to commands."""
        cmd_topic = f"devices/{self.device_id}/commands"
        resp_topic = f"devices/{self.device_id}/responses"
        
        # Subscribe to commands
        self.client.subscribe(cmd_topic, qos=1)
        
        # Publish a response
        payload = json.dumps({"status": "ready", "timestamp": int(time.time() * 1000)}).encode()
        
        start = time.time()
        self.client.publish(resp_topic, payload, qos=1)
        duration = time.time() - start
        
        events.request.fire(
            request_type=self.protocol.upper(),
            name="command_response",
            response_time=duration * 1000,
            response_length=len(payload),
            exception=None
        )
        self.last_publish = time.time()
    
    def _offline_test(self):
        """Offline device backlog test."""
        # Publish, disconnect, wait, reconnect
        topic = self.topic_pattern.replace("{deviceId}", self.device_id)
        
        # Publish before disconnect
        self.client.publish(topic, self._generate_payload(), qos=1)
        
        # Disconnect
        self.client.disconnect()
        time.sleep(random.uniform(1.0, 5.0))
        
        # Reconnect (clean_session=False should restore session)
        start = time.time()
        self.client.connect()
        duration = time.time() - start
        
        events.request.fire(
            request_type=self.protocol.upper(),
            name="offline_reconnect",
            response_time=duration * 1000,
            response_length=0,
            exception=None
        )
    
    def _lwt_test(self):
        """Last Will & Testament test."""
        # Normal publish - LWT is set on connect
        self._telemetry_test()
