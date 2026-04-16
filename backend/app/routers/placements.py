from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
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
    placement = Placement(
        user_id=user.id,
        level=body.level,
        level_label=body.level_label,
        confidence=body.confidence,
        highlight=body.highlight,
        transcript_json=body.transcript_json,
    )
    db.add(placement)

    # Also update user's current level
    user.level = body.level
    user.level_label = body.level_label
    db.add(user)

    await db.flush()
    return _out(placement)


@router.get("/latest", response_model=PlacementOut)
async def get_latest_placement(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
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
        level_label=p.level_label,
        confidence=p.confidence,
        highlight=p.highlight,
        created_at=p.created_at,
    )
