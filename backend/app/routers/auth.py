from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
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


async def _get_or_create_user_by_email(email: str, db: AsyncSession) -> tuple[User, bool]:
    """Look up a user by email, creating one if they don't exist.
    Returns (user, is_new). This is the canonical path for Google and magic-link login.
    device_id is no longer used for user identity.
    """
    email = email.lower().strip()

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    is_new = user is None
    if is_new:
        try:
            user = User(email=email)
            db.add(user)
            await db.flush()
        except IntegrityError:
            await db.rollback()
            result = await db.execute(select(User).where(User.email == email))
            user = result.scalar_one()
            is_new = False

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


@router.post("/anonymous", response_model=TokenResponse, deprecated=True)
async def anonymous_auth(
    body: AnonymousAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    """DEPRECATED: Anonymous auth via device_id is no longer used by the app.
    This endpoint is kept temporarily to avoid breaking old app versions still in the field.
    All new auth flows use Google Sign-In or Magic Link which identify users by email.
    """
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
            # We accept both Web and Android client IDs as valid audiences depending on how the frontend requested it.
            valid_audiences = [
                aud for aud in [settings.google_client_id, settings.google_web_client_id, settings.google_android_client_id] if aud
            ]
            idinfo = id_token.verify_oauth2_token(
                body.token, google_requests.Request(), valid_audiences
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

        user, is_new = await _get_or_create_user_by_email(email, db)
        return await _create_token_response(user, is_new, db)

    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid Google token")


@router.post("/magic-link/request")
async def request_magic_link(
    body: MagicLinkRequest,
):
    email = body.email.lower().strip()
    # device_id is no longer used — user identity is purely email-based
    token = create_magic_token(email, redirect_url=body.redirect_url)
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
    redirect_url = payload.get("redirect_url")

    user, is_new = await _get_or_create_user_by_email(email, db)
    
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
    separator = "&" if "?" in base_url else "?"
    final_url = f"{base_url}{separator}access_token={access_token}&refresh_token={refresh_token}&user_id={user.id}"

    playstore_url = "https://play.google.com/store/apps/details?id=org.navgurukul.ella"
    
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Authenticating...</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script>
            window.onload = function() {{
                var userAgent = navigator.userAgent || navigator.vendor || window.opera;
                var isAndroid = /android/i.test(userAgent);
                
                if (isAndroid) {{
                    // Try opening the app via Intent
                    setTimeout(function() {{
                        window.location.href = "intent://login?access_token={access_token}&refresh_token={refresh_token}&user_id={user.id}#Intent;scheme=ella;package=org.navgurukul.ella;end";
                    }}, 500);
                    
                    // Fallback to Play Store on Android
                    setTimeout(function() {{
                        window.location.href = "{playstore_url}";
                    }}, 3000);
                }} else {{
                    // Desktop/Other platforms: Redirect directly to final_url (ella:// scheme or frontend web app)
                    setTimeout(function() {{
                        window.location.href = "{final_url}";
                    }}, 500);
                }}

                // Update the instruction link dynamically
                var instructionLink = document.getElementById("instruction-link");
                if (instructionLink) {{
                    if (isAndroid) {{
                        instructionLink.href = "{playstore_url}";
                        instructionLink.innerText = "download it from the Play Store";
                    }} else {{
                        instructionLink.href = "{final_url}";
                        instructionLink.innerText = "open the application in your browser";
                    }}
                }}
            }};
        </script>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; text-align: center; padding-top: 50px; background-color: #f9fafb; color: #111827; }}
            .container {{ max-width: 400px; margin: 0 auto; padding: 20px; }}
            a {{ color: #4f46e5; text-decoration: none; font-weight: 600; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h2>Redirecting you to Ella...</h2>
            <p>If the app doesn't open automatically, <a id="instruction-link" href="{final_url}">open the application in your browser</a>.</p>
        </div>
    </body>
    </html>
    """
    
    from fastapi.responses import HTMLResponse
    return HTMLResponse(content=html_content)


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
