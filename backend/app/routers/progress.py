from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..models.conversation import Conversation
from ..models.placement import Placement
from pydantic import BaseModel

router = APIRouter(prefix="/progress", tags=["progress"])


class ProgressSummary(BaseModel):
    total_sessions: int
    completed_sessions: int
    total_speaking_seconds: int
    current_level: str | None = None
    placement_count: int


@router.get("/summary", response_model=ProgressSummary)
async def get_progress_summary(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    total = await db.execute(
        select(func.count()).select_from(Conversation).where(Conversation.user_id == user.id)
    )
    completed = await db.execute(
        select(func.count()).select_from(Conversation).where(
            Conversation.user_id == user.id, Conversation.completed == True
        )
    )
    speaking_time = await db.execute(
        select(func.coalesce(func.sum(Conversation.duration_seconds), 0)).where(
            Conversation.user_id == user.id
        )
    )
    placement_count = await db.execute(
        select(func.count()).select_from(Placement).where(Placement.user_id == user.id)
    )

    return ProgressSummary(
        total_sessions=total.scalar() or 0,
        completed_sessions=completed.scalar() or 0,
        total_speaking_seconds=speaking_time.scalar() or 0,
        current_level=user.level,
        placement_count=placement_count.scalar() or 0,
    )
