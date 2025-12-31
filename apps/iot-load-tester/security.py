"""Role-based access control for IoT Load Tester.

This module provides FastAPI dependencies for enforcing role-based access control.
Roles are read from the X-Auth-Request-Groups header set by OAuth2 Proxy.

Roles:
    admin: Full access to all endpoints
    test-telemetry: Access to telemetry tests and viewing results

Usage:
    from security import require_roles, require_admin
    
    @app.get("/endpoint", dependencies=[Depends(require_roles("test-telemetry"))])
    async def my_endpoint():
        ...
"""

from fastapi import Header, HTTPException, status
from typing import Optional, Set


class RoleChecker:
    """FastAPI dependency for role-based access control.
    
    Reads roles from X-Auth-Request-Groups header set by OAuth2 Proxy.
    The 'admin' role always has full access to all endpoints.
    """
    
    ADMIN_ROLE = "admin"
    
    def __init__(self, required_roles: Set[str] = None):
        """Create a role checker.
        
        Args:
            required_roles: Set of roles that can access the endpoint.
                           None or empty means admin-only.
                           Admin always has access regardless of this setting.
        """
        self.required_roles = required_roles or set()
    
    def __call__(
        self,
        # OAuth2 Proxy sets X-Auth-Request-* headers when set_xauthrequest=true
        x_auth_request_groups: Optional[str] = Header(None, alias="X-Auth-Request-Groups", include_in_schema=False),
        x_auth_request_user: Optional[str] = Header(None, alias="X-Auth-Request-User", include_in_schema=False),
    ) -> str:
        """Verify user has required role.
        
        Args:
            x_auth_request_groups: Comma-separated list of user roles from OAuth2 Proxy
            x_auth_request_user: Username from OAuth2 Proxy
            
        Returns:
            Username of authenticated user
            
        Raises:
            HTTPException: 403 if user lacks required role
        """
        user = x_auth_request_user or "anonymous"
        user_roles = self._parse_roles(x_auth_request_groups)
        
        # Admin always has access
        if self.ADMIN_ROLE in user_roles:
            return user
        
        # Check if user has any required role
        if self.required_roles and user_roles & self.required_roles:
            return user
        
        # No matching role - forbidden
        required = self.required_roles if self.required_roles else {self.ADMIN_ROLE}
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Access denied. Required roles: {sorted(required)}"
        )
    
    @staticmethod
    def _parse_roles(groups_header: Optional[str]) -> Set[str]:
        """Parse roles from comma-separated header value."""
        if not groups_header:
            return set()
        return {r.strip() for r in groups_header.split(",")}


def require_roles(*roles: str) -> RoleChecker:
    """Create a role checker for the specified roles.
    
    The 'admin' role always has access, even if not listed.
    
    Args:
        *roles: Role names that can access the endpoint
        
    Returns:
        RoleChecker instance for use as FastAPI dependency
        
    Example:
        @app.get("/tests", dependencies=[Depends(require_roles("test-telemetry"))])
        async def list_tests():
            ...
    """
    return RoleChecker(required_roles=set(roles))


# Pre-configured role checkers for common use cases
require_admin = RoleChecker()  # Admin only - no other roles accepted
