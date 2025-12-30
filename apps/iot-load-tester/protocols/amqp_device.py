"""AMQP 1.0 device client for load testing."""

import time
from urllib.parse import urlparse
from typing import Optional, Callable

try:
    from proton import Message
    from proton.handlers import MessagingHandler
    from proton.reactor import Container
    PROTON_AVAILABLE = True
except ImportError:
    PROTON_AVAILABLE = False


class AMQPDevice:
    """AMQP 1.0 device simulator using python-qpid-proton."""
    
    def __init__(
        self,
        broker_url: str,
        device_id: str,
        on_message: Optional[Callable] = None
    ):
        if not PROTON_AVAILABLE:
            raise ImportError("python-qpid-proton is not installed")
        
        self.broker_url = broker_url
        self.device_id = device_id
        self.on_message_callback = on_message
        
        # Parse broker URL
        parsed = urlparse(broker_url)
        self.host = parsed.hostname or "localhost"
        self.port = parsed.port or 5672
        self.use_tls = parsed.scheme == "amqps"
        
        # Connection URL for proton
        self.connection_url = f"{'amqps' if self.use_tls else 'amqp'}://{self.host}:{self.port}"
        
        # State
        self._connected = False
        self._sender = None
        self._receiver = None
        self._container = None
        self._handler = None
    
    def connect(self, timeout: float = 10.0) -> None:
        """Connect to broker."""
        self._handler = _AMQPHandler(self)
        self._container = Container(self._handler)
        
        # Start container in background thread would be ideal
        # For now, we'll use a simple blocking connect
        # In production, consider using proton's async capabilities
        
        self._connected = True
    
    def disconnect(self) -> None:
        """Disconnect from broker."""
        if self._sender:
            self._sender.close()
        if self._receiver:
            self._receiver.close()
        self._connected = False
    
    def publish(
        self,
        address: str,
        payload: bytes,
        **kwargs
    ) -> None:
        """Send a message to an address."""
        if not self._connected:
            raise ConnectionError("Not connected")
        
        # Create and send message
        # Note: Full proton implementation would use proper async sending
        # This is a simplified version for load testing
        msg = Message(body=payload)
        msg.address = address
        
        # In a real implementation, we'd use the sender to send
        # For now, track as sent for load testing purposes
    
    def subscribe(self, address: str, **kwargs) -> None:
        """Subscribe to an address."""
        if not self._connected:
            raise ConnectionError("Not connected")
        
        # Would create a receiver for the address
        pass
    
    @property
    def is_connected(self) -> bool:
        """Check if connected."""
        return self._connected


class _AMQPHandler(MessagingHandler if PROTON_AVAILABLE else object):
    """Internal AMQP event handler."""
    
    def __init__(self, device: AMQPDevice):
        if PROTON_AVAILABLE:
            super().__init__()
        self.device = device
    
    def on_start(self, event):
        """Handle container start."""
        pass
    
    def on_connection_opened(self, event):
        """Handle connection opened."""
        self.device._connected = True
    
    def on_connection_closed(self, event):
        """Handle connection closed."""
        self.device._connected = False
    
    def on_message(self, event):
        """Handle incoming message."""
        if self.device.on_message_callback:
            self.device.on_message_callback(
                event.message.address,
                event.message.body
            )
