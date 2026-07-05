from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
import json
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..models.placement import Placement
from ..schemas.placement import CreatePlacementRequest, PlacementOut

router = APIRouter(prefix="/placements", tags=["placements"])


@router.post("", response_model=PlacementOut)
async def create_placement(
    body: CreatePlacementRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Finalizes and saves the result of the voice placement screening test.
    
    - Creates a new placement history record.
    - Persists the assessed CEFR level, level label, highlight summary, and full transcript.
    - Updates the user's permanent profile with the graded level, level label, and interest tags.
    """
    placement = Placement(
        user_id=user.id,
        level=body.level,
        unit_label=body.unit_label,
        confidence=body.confidence,
        highlight=body.highlight,
        transcript_json=json.dumps(body.transcript_json) if body.transcript_json is not None else None,
    )
    db.add(placement)

    # Also update user's current level and interests
    user.level = body.level
    user.unit_label = body.unit_label
    if body.interests:
        user.interests = ",".join(body.interests)
    
    # Mark first_session_done so next_topics start showing immediately after placement
    if not user.first_session_done:
        user.first_session_done = True

    db.add(user)

    await db.flush()
    return _out(placement)


@router.get("/latest", response_model=PlacementOut)
async def get_latest_placement(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Fetches the student's latest active CEFR placement record.
    
    Used to initialize level-specific vocabulary and prompt constraints in subsequent chat screens.
    """
    result = await db.execute(
        select(Placement)
        .where(Placement.user_id == user.id)
        .order_by(desc(Placement.created_at))
        .limit(1)
    )
    placement = result.scalar_one_or_none()
    if not placement:
        raise HTTPException(status_code=404, detail="No placement found")
    return _out(placement)


@router.get("", response_model=list[PlacementOut])
async def list_placements(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Lists the full history of all completed voice placement tests for the authenticated student.
    
    Enables progress tracking and comparative reviews over time.
    """
    result = await db.execute(
        select(Placement)
        .where(Placement.user_id == user.id)
        .order_by(desc(Placement.created_at))
    )
    return [_out(p) for p in result.scalars().all()]


def _out(p: Placement) -> PlacementOut:
    return PlacementOut(
        id=p.id,
        level=p.level,
        unit_label=p.unit_label,
        confidence=p.confidence,
        highlight=p.highlight,
        created_at=p.created_at,
    )
