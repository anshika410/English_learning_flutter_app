from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import uuid
import httpx
from datetime import datetime, timezone, timedelta

from ..core.database import get_db
from ..core.security import create_access_token, create_magic_token, decode_magic_token, create_refresh_token
from ..core.email import send_magic_link_email
from ..core.config import get_settings
from ..models.user import User
from ..models.user import RefreshSession
from ..schemas.auth import AnonymousAuthRequest, TokenResponse, GoogleAuthRequest, MagicLinkRequest, RefreshRequest

router = APIRouter(prefix="/auth", tags=["auth"])


async def _handle_login_and_merge(email: str, device_id: str | None, db: AsyncSession) -> tuple[User, bool]:
    email = email.lower().strip()
    user = None

    if device_id:
        # 1. Look for anonymous user by device_id
        result = await db.execute(select(User).where(User.device_id == device_id))
        user = result.scalar_one_or_none()

    if user:
        if user.email and user.email != email:
            # Device ID is associated with a different email. Just lookup by email instead.
            result = await db.execute(select(User).where(User.email == email))
            user = result.scalar_one_or_none()
        else:
            # Anonymous account found. See if target email already exists.
            existing_email_result = await db.execute(select(User).where(User.email == email))
            existing_email_user = existing_email_result.scalar_one_or_none()

            if existing_email_user and existing_email_user.id != user.id:
                # Account already exists for this email. Use it (anonymous progress on device_id abandoned)
                user = existing_email_user
            else:
                # Merge: Upgrade anonymous account by adding the email
                user.email = email
                await db.flush()
    else:
        # No device_id or no user found with it, lookup by email
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()

    is_new = user is None
    if is_new:
        user = User(email=email, device_id=device_id or str(uuid.uuid4()))
        db.add(user)
        await db.flush()

    return user, is_new


async def _create_token_response(user: User, is_new: bool, db: AsyncSession) -> TokenResponse:
    settings = get_settings()
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token()

    session = RefreshSession(
        user_id=user.id,
        refresh_token=refresh_token,
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    )
    db.add(session)
    await db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user_id=user.id,
        is_new=is_new
    )


@router.post("/anonymous", response_model=TokenResponse)
async def anonymous_auth(
    body: AnonymousAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User).where(User.device_id == body.device_id)
    )
    user = result.scalar_one_or_none()
    is_new = user is None

    if is_new:
        user = User(device_id=body.device_id)
        db.add(user)
        await db.flush()

    return await _create_token_response(user, is_new, db)


@router.post("/google", response_model=TokenResponse)
async def google_auth(
    body: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    settings = get_settings()
    try:
        email = None
        # Check if the token is an ID Token (JWT) or an Access Token
        if body.token.count('.') == 2:
            # Verify the ID token with Google
            idinfo = id_token.verify_oauth2_token(
                body.token, google_requests.Request(), settings.google_client_id
            )
            email = idinfo.get("email")
        else:
            # Verify the Access token by hitting the userinfo endpoint
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    "https://www.googleapis.com/oauth2/v3/userinfo",
                    headers={"Authorization": f"Bearer {body.token}"}
                )
                if resp.status_code == 200:
                    email = resp.json().get("email")
                else:
                    raise ValueError("Invalid access token")

        if not email:
            raise HTTPException(status_code=400, detail="Google token does not contain email")

        user, is_new = await _handle_login_and_merge(email, body.device_id, db)
        return await _create_token_response(user, is_new, db)

    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid Google token")


@router.post("/magic-link/request")
async def request_magic_link(
    body: MagicLinkRequest,
):
    email = body.email.lower().strip()
    token = create_magic_token(email, device_id=body.device_id, redirect_url=body.redirect_url)
    send_magic_link_email(email, token)
    return {"message": "Email sent"}


@router.get("/magic-link/verify")
async def verify_magic_link(
    token: str,
    db: AsyncSession = Depends(get_db),
):
    # Decodes and verifies expiration/type
    payload = decode_magic_token(token)
    email = payload["email"]
    device_id = payload.get("device_id")
    redirect_url = payload.get("redirect_url")

    user, is_new = await _handle_login_and_merge(email, device_id, db)
    
    # We need to generate the refresh token and attach it to the redirect URL
    settings = get_settings()
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token()

    session = RefreshSession(
        user_id=user.id,
        refresh_token=refresh_token,
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    )
    db.add(session)
    await db.commit()

    base_url = redirect_url if redirect_url else settings.frontend_url
    # If the base URL already has parameters, append with &, otherwise ?
    separator = "&" if "?" in base_url else "?"
    final_url = f"{base_url}{separator}access_token={access_token}&refresh_token={refresh_token}"

    return RedirectResponse(url=final_url)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    body: RefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(RefreshSession).where(RefreshSession.refresh_token == body.refresh_token)
    )
    session = result.scalar_one_or_none()

    # Need tz-aware datetime comparison
    now = datetime.now(timezone.utc)
    if not session or session.revoked or session.expires_at < now:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    access_token = create_access_token(session.user_id)
    
    # We return the same refresh token, so they don't have to keep updating it locally
    return TokenResponse(
        access_token=access_token, 
        refresh_token=session.refresh_token, 
        user_id=session.user_id, 
        is_new=False
    )


@router.post("/logout")
async def logout(
    body: RefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(RefreshSession).where(RefreshSession.refresh_token == body.refresh_token)
    )
    session = result.scalar_one_or_none()
    if session:
        session.revoked = True
        await db.commit()
    return {"message": "Logged out"}
