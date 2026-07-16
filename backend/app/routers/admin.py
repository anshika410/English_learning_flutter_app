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
    email: str | None
    level: str | None
    unit_label: str | None
    total_sessions: int
    completed_sessions: int
    total_speaking_seconds: int
    created_at: datetime
    skills_progress: dict | None = None
    persona_memory: dict | None = None
    interests: str | None = None
    due_next: dict | None = None
    first_session_done: bool = False


class AdminConversationOut(BaseModel):
    id: str
    user_id: str
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
            email=u.email,
            level=u.level,
            unit_label=u.unit_label,
            total_sessions=stats["total"],
            completed_sessions=completed,
            total_speaking_seconds=stats["speaking_secs"],
            created_at=u.created_at,
            skills_progress=u.skills_progress,
            persona_memory=u.persona_memory,
            interests=u.interests,
            due_next=u.due_next,
            first_session_done=u.first_session_done,
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
            user_id=c.user_id,
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


@router.get("/conversations/{conversation_id}/analysis")
async def get_conversation_analysis(
    conversation_id: str,
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """PM-friendly session analysis — skills aimed, evidenced, state changes, miss reasons."""
    from ..models.session_analysis import SessionAnalysis
    from ..models.message import Message
    from ..core.curriculum_data import get_skill_text, FLOOR

    conv_result = await db.execute(select(Conversation).where(Conversation.id == conversation_id))
    conv = conv_result.scalar_one_or_none()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    user_result = await db.execute(select(User).where(User.id == conv.user_id))
    user = user_result.scalar_one_or_none()
    level = (user.level if user and user.level else "A1")

    msg_result = await db.execute(
        select(Message).where(Message.conversation_id == conversation_id)
        .order_by(Message.turn_number, Message.created_at)
    )
    transcript = [
        {"role": "zoe" if m.role in ("zoe", "assistant") else "me", "content": m.content}
        for m in msg_result.scalars().all()
    ]

    analysis_result = await db.execute(
        select(SessionAnalysis).where(SessionAnalysis.conversation_id == conversation_id)
    )
    sa = analysis_result.scalar_one_or_none()

    if not sa:
        return {
            "available": False,
            "session_id": conversation_id,
            "user_name": user.name if user else None,
            "level": level,
            "topic": conv.header_title or conv.topic,
            "turns_total": len([m for m in transcript if m["role"] == "me"]),
            "transcript": transcript,
            "message": "Analysis not available — conversation may still be in progress or analysis did not run.",
        }

    def miss_reason(confidence: float) -> str:
        if confidence >= FLOOR:
            return ""
        elif confidence >= 0.3:
            return "Evidence too weak — Zoe should elicit a clearer answer next time."
        else:
            return "No evidence found. Likely Zoe did not create a chance, learner stayed off-topic, or chat was too short."

    enriched_scores = []
    for sc in (sa.skills_evidenced or []):
        conf = sc.get("confidence", 0.0)
        enriched_scores.append({
            "id": sc.get("id", ""),
            "skill_text": get_skill_text(sc.get("id", ""), level),
            "confidence_pct": round(conf * 100),
            "prompted": sc.get("prompted", False),
            "evidence": sc.get("evidence", ""),
            "passed": conf >= FLOOR,
            "miss_reason": miss_reason(conf),
        })

    enriched_changes = [
        {
            "id": ch.get("id", ""),
            "skill_text": get_skill_text(ch.get("id", ""), level),
            "from": ch.get("from", ""),
            "to": ch.get("to", ""),
        }
        for ch in (sa.state_changes or [])
    ]

    # Reconstruct the system prompt and raw response for developer debugging
    judge_prompt = ""
    judge_response = {}
    try:
        from pathlib import Path
        import json
        PROMPTS_DIR = Path(__file__).parent.parent / "prompts"
        template = (PROMPTS_DIR / "end-result-prompt.md").read_text()
        
        # Format transcript
        formatted_transcript = "\n".join(
            f"{'STUDENT' if m['role'] == 'me' else 'ZOE'}: {m['content']}"
            for m in transcript
        )
        
        # Format target skills
        aimed_ids = sa.aimed_at or []
        id_list = "\n".join(f"- {sid}: {get_skill_text(sid, level)}" for sid in aimed_ids) if aimed_ids else "None"
        
        # Reconstruct the template (with target skills fix)
        template_fixed = template
        if "{{TARGET_SKILLS}}" not in template:
            template_fixed = template.replace("TRANSCRIPT:", "TARGET SKILLS:\n{{TARGET_SKILLS}}\n\nTRANSCRIPT:")
            
        judge_prompt = (
            template_fixed
            .replace("{{LEVEL}}", level)
            .replace("{{LEVEL_LABEL}}", "First Words" if level == "A0" else level)
            .replace("{{UNIT_LABEL}}", conv.topic or "First words")
            .replace("{{TOPIC}}", conv.header_title or conv.topic or "Free Talk")
            .replace("{{TARGET_SKILLS}}", id_list)
            .replace("{{FULL_TRANSCRIPT}}", formatted_transcript)
        )
        
        judge_response = {
            "overall": sa.overall,
            "zoe_recap": sa.zoe_recap,
            "best_moment": {
                "quote": sa.best_moment_quote,
                "note": sa.best_moment_note
            },
            "correction_highlight": sa.correction_highlight,
            "courage_or_motivation": {
                "type": sa.courage_type,
                "content": sa.courage_content
            },
            "try_next_time": {
                "skill": sa.try_next_skill,
                "example": sa.try_next_example
            },
            "scores": sa.skills_evidenced,
            "transcript_notes": json.loads(sa.transcript_notes_json or "[]")
        }
    except Exception as e:
        judge_prompt = f"Failed to reconstruct prompt: {str(e)}"

    return {
        "available": True,
        "session_id": conversation_id,
        "user_name": user.name if user else None,
        "level": level,
        "topic": conv.header_title or conv.topic,
        "turns_total": len([m for m in transcript if m["role"] == "me"]),
        "garden_grew": len(enriched_changes) > 0,
        "overall": sa.overall,
        "aimed_at": sa.aimed_at or [],
        "hit_targets": sa.hit_targets or [],
        "scores": enriched_scores,
        "state_changes": enriched_changes,
        "best_moment": {"quote": sa.best_moment_quote, "note": sa.best_moment_note},
        "courage": {"type": sa.courage_type, "content": sa.courage_content},
        "try_next": {"skill": sa.try_next_skill, "example": sa.try_next_example},
        "zoe_recap": sa.zoe_recap,
        "correction_highlight": sa.correction_highlight,
        "floor_pct": round(FLOOR * 100),
        "transcript": transcript,
        "judge_prompt": judge_prompt,
        "judge_response": judge_response,
    }


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
    """Get placement details + transcript for a user."""
    from ..models.placement import Placement
    import json
    result = await db.execute(
        select(Placement)
        .where(Placement.user_id == user_id)
        .order_by(desc(Placement.created_at))
        .limit(1)
    )
    placement = result.scalar_one_or_none()
    if not placement:
        return {"level": None, "confidence": None, "highlight": None, "unit_label": None, "created_at": None, "transcript": []}

    messages = []
    if placement.transcript_json:
        try:
            raw = json.loads(placement.transcript_json)
            messages = [
                {
                    "role": m.get("role", "user"),
                    "content": m.get("content", ""),
                }
                for m in raw
            ]
        except Exception:
            messages = []

    return {
        "level": placement.level,
        "confidence": placement.confidence,
        "highlight": placement.highlight,
        "unit_label": placement.unit_label,
        "created_at": placement.created_at.isoformat() if placement.created_at else None,
        "transcript": messages,
    }


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


class JumpRequest(BaseModel):
    email: str
    level: str  # A0, A1, A2, B1, B2, C1
    reset_progress: bool = False  # if True, wipes skills_progress so unit starts fresh


@router.post("/jump")
async def jump_user_to_level(
    body: JumpRequest,
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """
    🚀 Jump API — instantly move any user to any CEFR level by email.
    Perfect for QA and PM testing without going through placement.

    - email: the user's registered email address
    - level: one of A0, A1, A2, B1, B2, C1
    - reset_progress: set true to start fresh at Unit 1 of that level (recommended for clean testing)

    After calling this, just open the app — Zoe will immediately behave at the new level.
    """
    valid_levels = {"A0", "A1", "A2", "B1", "B2", "C1"}
    if body.level.upper() not in valid_levels:
        raise HTTPException(status_code=400, detail=f"Invalid level. Must be one of: {sorted(valid_levels)}")

    result = await db.execute(select(User).where(User.email == body.email.lower().strip()))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail=f"No user found with email '{body.email}'")

    user.level = body.level.upper()

    if body.reset_progress:
        user.skills_progress = {
            "owned": [], "emerging": [], "sightings": {},
            "strength": {}, "last_seen": {}, "effort": {"times_spoken_total": 0}
        }
        user.due_next = {}

    db.add(user)
    await db.flush()

    return {
        "status": "ok",
        "email": body.email,
        "level": user.level,
        "progress_reset": body.reset_progress,
        "message": f"User '{body.email}' is now at level {user.level}. Open the app to start a session.",
    }
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

