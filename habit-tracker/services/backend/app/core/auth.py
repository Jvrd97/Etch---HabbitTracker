# [review:need-review] PHASE-01/01-backend-api-key-auth
# summary: require_api_key dependency validating X-API-Key header against settings.API_KEY
"""
API-key authentication.

All API routers depend on `require_api_key`. The expected key comes from the
`API_KEY` env var; an empty value disables auth (dev mode) with a warning.
The key value itself is never logged.
"""

import logging
import secrets

from fastapi import Header, HTTPException, status

from app.core.config import settings

logger = logging.getLogger(__name__)


async def require_api_key(
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
) -> None:
    """Reject the request with 401 unless a valid X-API-Key header is present."""
    if not settings.API_KEY:
        logger.warning("API_KEY is not set; auth is DISABLED (dev mode)")
        return
    if x_api_key is None or not secrets.compare_digest(x_api_key, settings.API_KEY):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid API key",
        )
