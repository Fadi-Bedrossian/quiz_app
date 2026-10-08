from functools import lru_cache

import jwt
from fastapi import Depends, Header, HTTPException, status
from jwt import PyJWKClient

from .config import get_settings

settings = get_settings()


@lru_cache
def jwk_client():
    url = f"https://login.microsoftonline.com/{settings.entra_tenant_id}/discovery/v2.0/keys"
    return PyJWKClient(url)


def current_claims(authorization: str | None = Header(default=None)) -> dict:
    if settings.auth_disabled:
        return {"sub": "local-dev", "groups": [settings.admin_group_id] if settings.admin_group_id else []}
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    token = authorization.removeprefix("Bearer ").strip()
    try:
        key = jwk_client().get_signing_key_from_jwt(token).key
        # For Microsoft Entra v2 access tokens, the aud claim is the API's
        # Application (client) ID GUID even when the requested scope uses an
        # Application ID URI such as api://<client-id>/Quiz.Access.
        expected_audience = settings.entra_audience.removeprefix("api://")
        return jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=expected_audience,
            issuer=f"https://login.microsoftonline.com/{settings.entra_tenant_id}/v2.0",
        )
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid access token") from exc


def admin_claims(claims: dict = Depends(current_claims)) -> dict:
    if settings.auth_disabled:
        return claims
    if not settings.admin_group_id:
        raise HTTPException(status_code=403, detail="ADMIN_GROUP_ID is not configured")
    groups = claims.get("groups", [])
    if settings.admin_group_id not in groups:
        raise HTTPException(status_code=403, detail="Admin group membership required")
    return claims
