from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..core.database import get_db
from ..core.security import create_access_token
from ..models.user import User
from ..schemas.auth import AnonymousAuthRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/anonymous", response_model=TokenResponse)
async def anonymous_auth(
    body: AnonymousAuthRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Called once on first app launch with a device-generated UUID.
    - If device_id is new → creates a user account silently, returns token
    - If device_id exists → returns a fresh token for the existing user

    The app stores the token locally. On subsequent launches it just
    uses the stored token — this endpoint is only called if the token
    is missing or expired.
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

    token = create_access_token(user.id)
    return TokenResponse(access_token=token, user_id=user.id, is_new=is_new)
