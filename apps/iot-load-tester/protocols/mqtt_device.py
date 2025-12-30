"""MQTT device client for load testing with MQTT 5.0 support."""

import ssl
import time
from urllib.parse import urlparse
from typing import Optional, Callable

import paho.mqtt.client as mqtt
from paho.mqtt.properties import Properties
from paho.mqtt.packettypes import PacketTypes


class MQTTDevice:
    """MQTT 5.0 device simulator using paho-mqtt."""
    
    def __init__(
        self,
        broker_url: str,
        device_id: str,
        use_websockets: bool = False,
        clean_session: bool = True,
        qos: int = 1,
        message_expiry_seconds: Optional[int] = None,
        lwt_topic: Optional[str] = None,
        lwt_payload: Optional[bytes] = None,
        on_message: Optional[Callable] = None
    ):
        self.broker_url = broker_url
        self.device_id = device_id
        self.use_websockets = use_websockets
        self.clean_session = clean_session
        self.qos = qos
        self.message_expiry_seconds = message_expiry_seconds
        self.lwt_topic = lwt_topic
        self.lwt_payload = lwt_payload
        self.on_message_callback = on_message
        
        # Parse broker URL
        parsed = urlparse(broker_url)
        self.host = parsed.hostname or "localhost"
        self.port = parsed.port or (8883 if parsed.scheme in ["mqtts", "wss"] else 1883)
        self.use_tls = parsed.scheme in ["mqtts", "wss"]
        
        # Override WebSocket detection from URL
        if parsed.scheme in ["ws", "wss"]:
            self.use_websockets = True
        
        # Create MQTT 5.0 client
        transport = "websockets" if self.use_websockets else "tcp"
        self.client = mqtt.Client(
            client_id=device_id,
            protocol=mqtt.MQTTv5,
            transport=transport
        )
        
        # Set callbacks
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message
        
        # Set LWT with MQTT 5.0 properties
        lwt_properties = Properties(PacketTypes.WILLMESSAGE)
        if message_expiry_seconds:
            lwt_properties.MessageExpiryInterval = message_expiry_seconds
        
        if lwt_topic and lwt_payload:
            self.client.will_set(
                topic=lwt_topic,
                payload=lwt_payload,
                qos=1,
                retain=True,
                properties=lwt_properties
            )
        else:
            self.client.will_set(
                topic=f"devices/{device_id}/status",
                payload=b'{"online": false}',
                qos=1,
                retain=True,
                properties=lwt_properties
            )
        
        # State
        self._connected = False
        self._connect_error = None
    
    def _on_connect(self, client, userdata, flags, rc, properties=None):
        """Handle connection callback (MQTT 5.0 signature)."""
        if rc == 0:
            self._connected = True
        else:
            self._connect_error = f"Connect failed with code {rc}"
    
    def _on_disconnect(self, client, userdata, rc, properties=None):
        """Handle disconnect callback (MQTT 5.0 signature)."""
        self._connected = False
    
    def _on_message(self, client, userdata, msg):
        """Handle incoming message."""
        if self.on_message_callback:
            self.on_message_callback(msg.topic, msg.payload)
    
    def connect(self, timeout: float = 10.0) -> None:
        """Connect to broker."""
        # Configure TLS if needed
        if self.use_tls:
            self.client.tls_set(
                cert_reqs=ssl.CERT_NONE,
                tls_version=ssl.PROTOCOL_TLS
            )
            self.client.tls_insecure_set(True)
        
        # MQTT 5.0 connect properties
        connect_properties = Properties(PacketTypes.CONNECT)
        
        # Connect with clean_start (MQTT 5.0 equivalent of clean_session)
        self.client.connect(
            self.host, 
            self.port, 
            keepalive=60,
            clean_start=self.clean_session,
            properties=connect_properties
        )
        self.client.loop_start()
        
        # Wait for connection
        start = time.time()
        while not self._connected and (time.time() - start) < timeout:
            if self._connect_error:
                raise ConnectionError(self._connect_error)
            time.sleep(0.01)
        
        if not self._connected:
            raise ConnectionError(f"Connection timeout after {timeout}s")
    
    def disconnect(self) -> None:
        """Disconnect from broker."""
        self.client.loop_stop()
        self.client.disconnect()
        self._connected = False
    
    def publish(
        self,
        topic: str,
        payload: bytes,
        qos: Optional[int] = None,
        retain: bool = False,
        message_expiry: Optional[int] = None
    ) -> None:
        """Publish a message with optional MQTT 5.0 message expiry."""
        if not self._connected:
            raise ConnectionError("Not connected")
        
        # Build publish properties for MQTT 5.0
        publish_properties = Properties(PacketTypes.PUBLISH)
        
        # Set message expiry (use per-message, then instance default)
        expiry = message_expiry or self.message_expiry_seconds
        if expiry:
            publish_properties.MessageExpiryInterval = expiry
        
        result = self.client.publish(
            topic=topic,
            payload=payload,
            qos=qos if qos is not None else self.qos,
            retain=retain,
            properties=publish_properties
        )
        
        # Wait for publish to complete for QoS > 0
        if (qos or self.qos) > 0:
            result.wait_for_publish(timeout=5.0)
    
    def subscribe(self, topic: str, qos: Optional[int] = None) -> None:
        """Subscribe to a topic."""
        if not self._connected:
            raise ConnectionError("Not connected")
        
        self.client.subscribe(topic, qos=qos if qos is not None else self.qos)
    
    def unsubscribe(self, topic: str) -> None:
        """Unsubscribe from a topic."""
        if not self._connected:
            raise ConnectionError("Not connected")
        
        self.client.unsubscribe(topic)
    
    @property
    def is_connected(self) -> bool:
        """Check if connected."""
        return self._connected
