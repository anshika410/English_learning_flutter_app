from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
from fastapi import HTTPException
from .config import get_settings


def create_access_token(user_id: str) -> str:
    settings = get_settings()
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.access_token_expire_minutes
    )
    payload = {"sub": user_id, "exp": expire}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> str:
    """Returns user_id or raises 401."""
    settings = get_settings()
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
        user_id: str = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token")
        return user_id
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

import secrets

def create_refresh_token() -> str:
    # A refresh token should be a secure, random string (not necessarily a JWT)
    # stored in the database so it can be revoked.
    return secrets.token_urlsafe(64)


def create_magic_token(email: str, device_id: str | None = None, redirect_url: str | None = None) -> str:
    settings = get_settings()
    expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    payload = {
        "sub": email,
        "exp": expire,
        "type": "magic_link"
    }
    if device_id:
        payload["device_id"] = device_id
    if redirect_url:
        payload["redirect_url"] = redirect_url
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)

def decode_magic_token(token: str) -> dict:
    settings = get_settings()
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
        if payload.get("type") != "magic_link":
            raise HTTPException(status_code=400, detail="Invalid token type")
        email: str = payload.get("sub")
        if not email:
            raise HTTPException(status_code=400, detail="Invalid token")
        return {
            "email": email, 
            "device_id": payload.get("device_id"),
            "redirect_url": payload.get("redirect_url")
        }
    except JWTError:
        raise HTTPException(status_code=400, detail="Invalid or expired magic link token")
