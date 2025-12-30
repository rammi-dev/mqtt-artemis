"""HTTP client for bootstrap and diagnostics."""

import time
from typing import Optional, Dict, Any

import httpx


class HTTPClient:
    """HTTP client for REST API load testing."""
    
    def __init__(
        self,
        base_url: str,
        device_id: str,
        timeout: float = 30.0
    ):
        self.base_url = base_url.rstrip("/")
        self.device_id = device_id
        self.timeout = timeout
        
        # Create client
        self._client = httpx.Client(
            base_url=self.base_url,
            timeout=timeout,
            verify=False  # Allow self-signed certs
        )
        self._connected = False
    
    def connect(self, timeout: float = 10.0) -> None:
        """Initialize connection (health check)."""
        try:
            response = self._client.get("/health", timeout=timeout)
            response.raise_for_status()
            self._connected = True
        except Exception as e:
            # Try root path if /health doesn't exist
            try:
                response = self._client.get("/", timeout=timeout)
                self._connected = True
            except Exception:
                raise ConnectionError(f"Cannot connect to {self.base_url}: {e}")
    
    def disconnect(self) -> None:
        """Close connection."""
        self._client.close()
        self._connected = False
    
    def publish(
        self,
        path: str,
        payload: bytes,
        method: str = "POST",
        headers: Optional[Dict[str, str]] = None,
        **kwargs
    ) -> httpx.Response:
        """Send an HTTP request (analogous to publish for other protocols)."""
        if not self._connected:
            raise ConnectionError("Not connected")
        
        request_headers = {
            "Content-Type": "application/json",
            "X-Device-Id": self.device_id
        }
        if headers:
            request_headers.update(headers)
        
        if method.upper() == "POST":
            response = self._client.post(path, content=payload, headers=request_headers)
        elif method.upper() == "PUT":
            response = self._client.put(path, content=payload, headers=request_headers)
        elif method.upper() == "GET":
            response = self._client.get(path, headers=request_headers)
        elif method.upper() == "DELETE":
            response = self._client.delete(path, headers=request_headers)
        else:
            raise ValueError(f"Unsupported method: {method}")
        
        return response
    
    def subscribe(self, path: str, **kwargs) -> None:
        """HTTP doesn't support subscription - this is a no-op."""
        pass
    
    def get(self, path: str, **kwargs) -> httpx.Response:
        """GET request."""
        return self._client.get(path, **kwargs)
    
    def post(self, path: str, data: Any = None, **kwargs) -> httpx.Response:
        """POST request."""
        return self._client.post(path, json=data, **kwargs)
    
    @property
    def is_connected(self) -> bool:
        """Check if connected."""
        return self._connected
