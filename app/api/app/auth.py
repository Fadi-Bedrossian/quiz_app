from functools import lru_cache

import jwt
from fastapi import Depends, Header, HTTPException, status
from jwt import PyJWKClient

from .config import get_settings

settings = get_settings()


@lru_cache
def jwk_client() -> PyJWKClient:
    url = f"https://login.microsoftonline.com/{settings.entra_tenant_id}/discovery/v2.0/keys"
    return PyJWKClient(url)


def allowed_audiences() -> list[str]:
    configured = settings.entra_audience.strip()
    if not configured:
        return []
    audiences = [configured]
    if configured.startswith("api://"):
        client_id = configured.removeprefix("api://")
        if client_id:
            audiences.append(client_id)
    return audiences


def current_claims(authorization: str | None = Header(default=None)) -> dict:
    if not settings.entra_tenant_id or not settings.entra_audience:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin authentication is not configured",
        )
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )

    token = authorization.removeprefix("Bearer ").strip()
    try:
        key = jwk_client().get_signing_key_from_jwt(token).key
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=allowed_audiences(),
            issuer=f"https://login.microsoftonline.com/{settings.entra_tenant_id}/v2.0",
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token",
        ) from exc

    scopes = set(str(claims.get("scp", "")).split())
    if "Quiz.Access" not in scopes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Quiz.Access scope required",
        )
    return claims


def admin_claims(claims: dict = Depends(current_claims)) -> dict:
    if not settings.admin_group_id:
        return claims

    groups = claims.get("groups", [])
    if settings.admin_group_id not in groups:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin group membership required",
        )
    return claims
