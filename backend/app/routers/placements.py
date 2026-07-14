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
    
    # Auto-own all skills from levels below the placed level.
    # If a student is placed at B2, they have demonstrated proficiency at A0-B1
    # already, so all those lower-level skills should show as owned in the garden.
    from ..core.curriculum_data import UNITS
    from sqlalchemy.orm.attributes import flag_modified

    LEVEL_ORDER = ["A0", "A1", "A2", "B1", "B2", "C1"]
    placed_level = body.level.upper()
    if placed_level in LEVEL_ORDER:
        placed_idx = LEVEL_ORDER.index(placed_level)
        levels_to_backfill = LEVEL_ORDER[:placed_idx]  # all levels below placed level

        progress = user.skills_progress or {}
        if not isinstance(progress, dict):
            progress = {}
        if "owned" not in progress:
            progress["owned"] = []
        if "emerging" not in progress:
            progress["emerging"] = []
        if "sightings" not in progress:
            progress["sightings"] = {}
        if "strength" not in progress:
            progress["strength"] = {}
        if "last_seen" not in progress:
            progress["last_seen"] = {}
        if "effort" not in progress:
            progress["effort"] = {"times_spoken_total": 0}

        from datetime import datetime, timezone
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        for lvl in levels_to_backfill:
            for unit in UNITS.get(lvl, []):
                for skill in unit.get("skills", []):
                    sid = skill["id"]
                    if sid not in progress["owned"]:
                        progress["owned"].append(sid)
                    # Remove from emerging if it was there
                    if sid in progress["emerging"]:
                        progress["emerging"].remove(sid)
                    # Mark as seen today with strong sightings
                    if sid not in progress["sightings"]:
                        progress["sightings"][sid] = 3
                    if sid not in progress["last_seen"]:
                        progress["last_seen"][sid] = today

        user.skills_progress = progress
        flag_modified(user, "skills_progress")
    
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
