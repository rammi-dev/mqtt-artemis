"""
Dagster Resources for Edge Analytics

Configurable connections to ClickHouse and Redis.
"""

import os
from dagster import ConfigurableResource, InitResourceContext
import clickhouse_connect
import redis


class ClickHouseResource(ConfigurableResource):
    """ClickHouse database connection resource."""
    
    host: str = os.getenv("CLICKHOUSE_HOST", "localhost")
    port: int = int(os.getenv("CLICKHOUSE_PORT", "8123"))
    user: str = os.getenv("CLICKHOUSE_USER", "admin")
    password: str = os.getenv("CLICKHOUSE_PASSWORD", "password")
    database: str = "telemetry"
    
    def get_client(self):
        """Get a ClickHouse client connection."""
        return clickhouse_connect.get_client(
            host=self.host,
            port=self.port,
            username=self.user,
            password=self.password,
            database=self.database,
        )
    
    def execute(self, query: str):
        """Execute a query and return results."""
        client = self.get_client()
        return client.query(query)
    
    def execute_command(self, command: str):
        """Execute a command (INSERT, CREATE, etc.)."""
        client = self.get_client()
        return client.command(command)


class RedisResource(ConfigurableResource):
    """Redis connection resource."""
    
    host: str = os.getenv("REDIS_HOST", "localhost")
    port: int = int(os.getenv("REDIS_PORT", "6379"))
    password: str = os.getenv("REDIS_PASSWORD", "")
    db: int = 0
    
    def get_client(self):
        """Get a Redis client connection."""
        return redis.Redis(
            host=self.host,
            port=self.port,
            password=self.password if self.password else None,
            db=self.db,
            decode_responses=True,
        )
    
    def set_json(self, key: str, data: dict, ttl: int = None):
        """Set a JSON value with optional TTL."""
        import json
        client = self.get_client()
        client.set(key, json.dumps(data), ex=ttl)
    
    def get_json(self, key: str):
        """Get a JSON value."""
        import json
        client = self.get_client()
        data = client.get(key)
        return json.loads(data) if data else None


# Resource instances for the Definitions
clickhouse_resource = ClickHouseResource()
redis_resource = RedisResource()
