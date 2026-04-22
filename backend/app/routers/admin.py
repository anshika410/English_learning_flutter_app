"""Read-only admin stats endpoint — protected by a secret key in the query string."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, Integer
from ..core.database import get_db
from ..core.config import get_settings
from ..models.user import User
from ..models.conversation import Conversation
from ..models.message import Message
from ..models.placement import Placement
from pydantic import BaseModel
from datetime import datetime

router = APIRouter(prefix="/admin", tags=["admin"])


def _check_key(key: str = Query(..., alias="key")):
    settings = get_settings()
    if key != settings.admin_secret_key:
        raise HTTPException(status_code=403, detail="Invalid admin key")


# ── Response models ───────────────────────────────────────────────────────────

class AdminUserOut(BaseModel):
    id: str
    name: str | None
    age: str | None
    location: str | None
    level: str | None
    level_label: str | None
    total_sessions: int
    completed_sessions: int
    total_speaking_seconds: int
    created_at: datetime


class AdminConversationOut(BaseModel):
    id: str
    user_name: str | None
    user_level: str | None
    topic: str | None
    header_title: str | None
    duration_seconds: int | None
    completed: bool
    message_count: int
    created_at: datetime


class AdminStatsOut(BaseModel):
    total_users: int
    total_sessions: int
    completed_sessions: int
    total_speaking_minutes: float
    level_distribution: dict[str, int]
    users: list[AdminUserOut]
    recent_conversations: list[AdminConversationOut]


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/stats", response_model=AdminStatsOut)
async def admin_stats(
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    # All users
    users_result = await db.execute(
        select(User).order_by(desc(User.created_at))
    )
    users = users_result.scalars().all()

    # Per-user session counts
    session_counts = await db.execute(
        select(
            Conversation.user_id,
            func.count().label("total"),
            func.sum(func.cast(Conversation.completed, Integer)).label("completed"),
            func.coalesce(func.sum(Conversation.duration_seconds), 0).label("speaking_secs"),
        ).group_by(Conversation.user_id)
    )
    session_map = {
        row.user_id: {
            "total": row.total,
            "completed": row.completed or 0,
            "speaking_secs": row.speaking_secs or 0,
        }
        for row in session_counts
    }

    # Build user list
    user_list = []
    level_dist: dict[str, int] = {}
    total_sessions = 0
    total_completed = 0
    total_speaking_secs = 0

    for u in users:
        stats = session_map.get(u.id, {"total": 0, "completed": 0, "speaking_secs": 0})
        total_sessions += stats["total"]
        total_completed += stats["completed"]
        total_speaking_secs += stats["speaking_secs"]
        if u.level:
            level_dist[u.level] = level_dist.get(u.level, 0) + 1
        user_list.append(AdminUserOut(
            id=u.id,
            name=u.name,
            age=u.age,
            location=u.location,
            level=u.level,
            level_label=u.level_label,
            total_sessions=stats["total"],
            completed_sessions=stats["completed"],
            total_speaking_seconds=stats["speaking_secs"],
            created_at=u.created_at,
        ))

    # Recent conversations with message counts
    convs_result = await db.execute(
        select(Conversation).order_by(desc(Conversation.created_at)).limit(50)
    )
    convs = convs_result.scalars().all()

    msg_counts = await db.execute(
        select(
            Message.conversation_id,
            func.count().label("cnt"),
        ).group_by(Message.conversation_id)
    )
    msg_map = {row.conversation_id: row.cnt for row in msg_counts}

    user_map = {u.id: u for u in users}
    conv_list = []
    for c in convs:
        u = user_map.get(c.user_id)
        conv_list.append(AdminConversationOut(
            id=c.id,
            user_name=u.name if u else None,
            user_level=u.level if u else None,
            topic=c.topic,
            header_title=c.header_title,
            duration_seconds=c.duration_seconds,
            completed=c.completed,
            message_count=msg_map.get(c.id, 0),
            created_at=c.created_at,
        ))

    return AdminStatsOut(
        total_users=len(users),
        total_sessions=total_sessions,
        completed_sessions=total_completed,
        total_speaking_minutes=round(total_speaking_secs / 60, 1),
        level_distribution=level_dist,
        users=user_list,
        recent_conversations=conv_list,
    )


@router.get("/conversations/{conversation_id}/transcript")
async def get_transcript(
    conversation_id: str,
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """Get full transcript for a conversation."""
    msgs_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.turn_number, Message.created_at)
    )
    msgs = msgs_result.scalars().all()
    return [
        {
            "role": m.role,
            "content": m.content,
            "correction": m.correction,
            "turn_number": m.turn_number,
            "stt_ms": m.stt_duration_ms,
            "llm_ms": m.llm_duration_ms,
            "tts_ms": m.tts_duration_ms,
            "created_at": m.created_at.isoformat(),
        }
        for m in msgs
    ]
