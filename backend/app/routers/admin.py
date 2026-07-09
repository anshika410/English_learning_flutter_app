"""Read-only admin stats endpoint — protected by a secret key in the query string."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
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
    unit_label: str | None
    total_sessions: int
    completed_sessions: int
    total_speaking_seconds: int
    created_at: datetime
    skills_progress: dict | None = None


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
            func.coalesce(func.sum(Conversation.duration_seconds), 0).label("speaking_secs"),
        ).group_by(Conversation.user_id)
    )
    session_map = {
        row.user_id: {
            "total": row.total,
            "speaking_secs": row.speaking_secs or 0,
        }
        for row in session_counts
    }

    # Completed counts per user
    completed_counts = await db.execute(
        select(
            Conversation.user_id,
            func.count().label("cnt"),
        ).where(Conversation.completed == True).group_by(Conversation.user_id)
    )
    completed_map = {row.user_id: row.cnt for row in completed_counts}

    # Build user list
    user_list = []
    level_dist: dict[str, int] = {}
    total_sessions = 0
    total_completed = 0
    total_speaking_secs = 0

    for u in users:
        stats = session_map.get(u.id, {"total": 0, "speaking_secs": 0})
        completed = completed_map.get(u.id, 0)
        total_sessions += stats["total"]
        total_completed += completed
        total_speaking_secs += stats["speaking_secs"]
        if u.level:
            level_dist[u.level] = level_dist.get(u.level, 0) + 1
        user_list.append(AdminUserOut(
            id=u.id,
            name=u.name,
            age=u.age,
            location=u.location,
            level=u.level,
            unit_label=u.unit_label,
            total_sessions=stats["total"],
            completed_sessions=completed,
            total_speaking_seconds=stats["speaking_secs"],
            created_at=u.created_at,
            skills_progress=u.skills_progress,
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


@router.get("/placements/{user_id}/transcript")
async def get_placement_transcript(
    user_id: str,
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """Get placement transcript for a user."""
    from ..models.placement import Placement
    import json
    result = await db.execute(
        select(Placement)
        .where(Placement.user_id == user_id)
        .order_by(desc(Placement.created_at))
        .limit(1)
    )
    placement = result.scalar_one_or_none()
    if not placement or not placement.transcript_json:
        return []
    try:
        messages = json.loads(placement.transcript_json)
        return [
            {
                "role": m.get("role", "user"),
                "content": m.get("content", ""),
            }
            for m in messages
        ]
    except Exception:
        return []


class AdminPromptsResponse(BaseModel):
    conversation: str
    judge: str
    placement: str
    correction_extraction: str
    base: str
    level_profiles: dict[str, str]
    conv_unit_framing: str


@router.get("/prompts", response_model=AdminPromptsResponse)
async def get_admin_prompts():
    """Get active LLM prompt templates — modular building blocks matching client structure."""
    from ..services.llm_service import PROMPTS_DIR, extract_correction_highlight
    import inspect, re
    try:
        conv = (PROMPTS_DIR / "conversation-prompt.md").read_text()
        judge = (PROMPTS_DIR / "end-result-prompt.md").read_text()
        placement = (PROMPTS_DIR / "placement-check-prompt.md").read_text()
        
        # Read modular prompt files
        base = (PROMPTS_DIR / "base-prompt.md").read_text()
        conv_unit_framing = (PROMPTS_DIR / "conv-unit-framing.md").read_text()
        
        # Read level profiles
        level_profiles = {}
        for lvl in ["A0", "A1", "A2", "B1", "B2", "C1"]:
            profile_path = PROMPTS_DIR / f"profile-{lvl}.md"
            if profile_path.exists():
                level_profiles[lvl] = profile_path.read_text()
            else:
                level_profiles[lvl] = f"(No profile file for {lvl})"

        # Extract correction prompt from function source
        correction_src = inspect.getsource(extract_correction_highlight)
        prompt_match = re.search(r'prompt = f"""(.+?)"""', correction_src, re.DOTALL)
        correction_prompt = prompt_match.group(1).strip() if prompt_match else "See llm_service.py → extract_correction_highlight()"

        return AdminPromptsResponse(
            conversation=conv,
            judge=judge,
            placement=placement,
            correction_extraction=correction_prompt,
            base=base,
            level_profiles=level_profiles,
            conv_unit_framing=conv_unit_framing,
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to read prompt templates: {e}"
        )


@router.delete("/reset-user/{device_id}")
async def reset_user(
    device_id: str,
    db: AsyncSession = Depends(get_db),
):
    """
    DEV ONLY — Deletes all placement records for a user and resets their level to null.
    Use this to re-test placement flow from scratch.
    """
    result = await db.execute(select(User).where(User.device_id == device_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail=f"User with device_id '{device_id}' not found")

    # Delete placements
    await db.execute(
        select(Placement).where(Placement.user_id == user.id)
    )
    from sqlalchemy import delete
    await db.execute(delete(Placement).where(Placement.user_id == user.id))

    # Reset user fields
    user.level = None
    user.level_label = None
    user.first_session_done = False
    user.skills_progress = {}
    user.due_next = {}
    user.interests = None
    user.persona_memory = {}
    db.add(user)
    await db.flush()

    return {
        "status": "reset",
        "device_id": device_id,
        "user_id": user.id,
        "message": "All placements deleted. Level, skills, memory reset to fresh state."
    }


@router.get("/curriculum")
async def get_admin_curriculum(
    _: None = Depends(_check_key),
):
    """Get dynamic curriculum structure representing levels, steps, and flat skills."""
    from ..core.curriculum_data import UNITS
    return UNITS

