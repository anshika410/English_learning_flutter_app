"""Read-only admin stats endpoint — protected by a secret key in the query string."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, Table, Column, String, Text, DateTime, MetaData, Integer
from sqlalchemy.dialects.postgresql import JSONB
from ..core.database import get_db
from ..core.config import get_settings
from ..core.deps import get_current_user
from ..models.user import User
from ..models.conversation import Conversation
from ..models.message import Message
from ..models.placement import Placement
from pydantic import BaseModel
from datetime import datetime
from ..core.database import Base

router = APIRouter(prefix="/admin", tags=["admin"])

# Prompt version history table (lightweight, no ORM model needed)
metadata = MetaData()
prompt_history_table = Table(
    "prompt_history", Base.metadata,
    Column("id", String(36), primary_key=True, default=lambda: __import__('uuid').uuid4().hex),
    Column("prompt_name", String(100)),
    Column("content", Text),
    Column("author", String(100)),
    Column("created_at", DateTime(timezone=True)),
    extend_existing=True,
)

# Simple versioning table — one row per deploy, covers ALL files as a snapshot
prompt_versions_table = Table(
    "prompt_versions", Base.metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("version", String(20)),      # e.g. "v0.0.1"
    Column("author", String(100)),
    Column("notes", Text, default=""),
    Column("snapshot", JSONB),           # {"base-prompt": "...", "profile-A0": "...", ...}
    Column("created_at", DateTime(timezone=True)),
    extend_existing=True,
)


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
    from ..core.config import get_settings
    settings = get_settings()

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
        {"role": "zoe" if m.role in ("zoe", "assistant") else "me", "content": m.content, "input_mode": m.input_mode}
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
            "message": "Judge response is not available — conversation may still be in progress or judge did not run.",
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
            "support_level": sc.get("support_level"),
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
        from ..services.llm_service import resolve_prompt
        template = resolve_prompt("end-result-prompt.md", user_id=conv.user_id)
        
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
        "prompt_used": conv.prompt_used,
        "judge_prompt": judge_prompt,
        "judge_response": judge_response,
        "judge_endpoint": f"{settings.deepseek_base_url}/chat/completions",
        "judge_model": settings.deepseek_model,
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
            "input_mode": m.input_mode,
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
    is_sandbox: bool = False


@router.get("/prompts", response_model=AdminPromptsResponse)
async def get_admin_prompts(
    user: User = Depends(get_current_user),
):
    """Get active LLM prompt templates — modular building blocks matching client structure."""
    from ..services.llm_service import PROMPTS_DIR, resolve_prompt
    try:
        user_id = user.id if user else None
        
        # Check if sandbox exists for this user
        is_sandbox = False
        if user_id:
            sandbox_dir = PROMPTS_DIR / "sandboxes" / user_id
            if sandbox_dir.exists() and any(sandbox_dir.iterdir()):
                is_sandbox = True

        conv = resolve_prompt("conversation-prompt.md", user_id=user_id)
        judge = resolve_prompt("end-result-prompt.md", user_id=user_id)
        placement = resolve_prompt("placement-check-prompt.md", user_id=user_id)
        base = resolve_prompt("base-prompt.md", user_id=user_id)
        conv_unit_framing = resolve_prompt("conv-unit-framing.md", user_id=user_id)
        correction_prompt = resolve_prompt("correction-extraction-prompt.md", user_id=user_id)
        
        # Read level profiles
        level_profiles = {}
        for lvl in ["A0", "A1", "A2", "B1", "B2", "C1"]:
            level_profiles[lvl] = resolve_prompt(f"profile-{lvl}.md", user_id=user_id)

        return AdminPromptsResponse(
            conversation=conv,
            judge=judge,
            placement=placement,
            correction_extraction=correction_prompt,
            base=base,
            level_profiles=level_profiles,
            conv_unit_framing=conv_unit_framing,
            is_sandbox=is_sandbox,
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to read prompt templates: {e}"
        )


class PromptSandboxDeployRequest(BaseModel):
    snapshot: dict[str, str]

@router.post("/prompts/sandbox")
async def deploy_sandbox_prompts(
    body: PromptSandboxDeployRequest,
    user: User = Depends(get_current_user),
):
    """
    Saves developer's custom prompts to their personal sandbox folder on disk.
    These prompts will be used for all their chats in the simulator and app,
    without affecting any other user.
    """
    from ..services.llm_service import PROMPTS_DIR
    import os
    
    valid_names = [
        "base-prompt", "conversation-prompt", "conv-unit-framing",
        "end-result-prompt", "placement-check-prompt",
        "correction-extraction-prompt",
        "profile-A0", "profile-A1", "profile-A2",
        "profile-B1", "profile-B2", "profile-C1",
    ]
    
    # Validate keys
    for name in body.snapshot:
        clean_name = name.replace(".md", "")
        if clean_name not in valid_names:
            raise HTTPException(status_code=400, detail=f"Invalid prompt name: {name}")
            
    try:
        # Create sandbox folder for this user
        sandbox_dir = PROMPTS_DIR / "sandboxes" / user.id
        os.makedirs(sandbox_dir, exist_ok=True)
        
        # Save the files
        for name, content in body.snapshot.items():
            filename = name if name.endswith(".md") else f"{name}.md"
            target = sandbox_dir / filename
            target.write_text(content)
            
        return {"status": "success", "message": f"Saved {len(body.snapshot)} prompts to your sandbox"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Filesystem error: {str(e)} (Check write permissions for {PROMPTS_DIR})")


@router.delete("/prompts/sandbox")
async def clear_sandbox_prompts(
    user: User = Depends(get_current_user),
):
    """Clears the developer's sandbox prompts folder."""
    from ..services.llm_service import PROMPTS_DIR
    import shutil
    
    sandbox_dir = PROMPTS_DIR / "sandboxes" / user.id
    try:
        if sandbox_dir.exists():
            shutil.rmtree(sandbox_dir)
        return {"status": "success", "message": "Cleared sandbox prompts"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Filesystem error: {str(e)}")


class PromptTestRequest(BaseModel):
    system_prompt: str
    messages: list[dict] = []  # [{"role": "user", "content": "..."}, ...]
    max_tokens: int = 300
    temperature: float = 0.75


@router.post("/prompts/test")
async def test_prompt(
    body: PromptTestRequest,
    _: None = Depends(_check_key),
):
    """Test a prompt with the LLM — isolated, never touches production or any user."""
    from ..core.config import get_settings
    import httpx

    settings = get_settings()
    api_messages = [{"role": "system", "content": body.system_prompt}] + body.messages

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                f"{settings.deepseek_base_url}/chat/completions",
                headers={"Authorization": f"Bearer {settings.deepseek_api_key}"},
                json={
                    "model": settings.deepseek_model,
                    "messages": api_messages,
                    "max_tokens": body.max_tokens,
                    "temperature": body.temperature,
                },
            )
            data = resp.json()
            reply = data.get("choices", [{}])[0].get("message", {}).get("content", "")
            usage = data.get("usage", {})
            return {
                "reply": reply,
                "usage": usage,
                "model": data.get("model"),
                "prompt_sent": body.system_prompt,
            }
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM call failed: {e}")


class PromptDeployRequest(BaseModel):
    prompt_name: str  # e.g. "base-prompt", "profile-A0", "end-result-prompt"
    content: str
    author: str = "unknown"  # who deployed this


@router.put("/prompts/deploy")
async def deploy_prompt(
    body: PromptDeployRequest,
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """Deploy a prompt to production — overwrites the .md file. USE WITH CAUTION."""
    raise HTTPException(status_code=403, detail="Deploy feature is currently disabled.")
    from ..services.llm_service import PROMPTS_DIR

    # Validate prompt name
    valid_names = [
        "base-prompt", "conversation-prompt", "conv-unit-framing",
        "end-result-prompt", "placement-check-prompt",
        "correction-extraction-prompt", "starter-prompt",
        "profile-A0", "profile-A1", "profile-A2",
        "profile-B1", "profile-B2", "profile-C1",
    ]
    if body.prompt_name not in valid_names:
        raise HTTPException(status_code=400, detail=f"Invalid prompt name. Valid: {valid_names}")

    target = PROMPTS_DIR / f"{body.prompt_name}.md"
    if not target.exists():
        raise HTTPException(status_code=404, detail=f"Prompt file not found: {body.prompt_name}.md")

    # Save current version to history before overwriting
    old_content = target.read_text()
    from datetime import datetime, timezone
    await db.execute(
        prompt_history_table.insert().values(
            prompt_name=body.prompt_name,
            content=old_content,
            author=body.author,
            created_at=datetime.now(timezone.utc),
        )
    )
    await db.commit()

    # Backup current version as .bak file too
    backup = PROMPTS_DIR / f"{body.prompt_name}.md.bak"
    backup.write_text(old_content)

    # Write new content
    target.write_text(body.content)

    return {
        "status": "deployed",
        "prompt_name": body.prompt_name,
        "chars": len(body.content),
        "backup": f"{body.prompt_name}.md.bak",
    }


@router.get("/prompts/history")
async def get_prompt_history(
    prompt_name: str = Query(None),
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """Get version history for prompts. Optionally filter by prompt_name."""
    query = select(prompt_history_table).order_by(desc(prompt_history_table.c.created_at)).limit(50)
    if prompt_name:
        query = query.where(prompt_history_table.c.prompt_name == prompt_name)
    result = await db.execute(query)
    rows = result.fetchall()
    return [
        {
            "id": row.id,
            "prompt_name": row.prompt_name,
            "content": row.content,
            "author": row.author,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        }
        for row in rows
    ]


# ── Simple Prompt Versioning (v0.0.1 style) ──────────────────────────────────

class PromptDeployAllRequest(BaseModel):
    author: str
    notes: str = ""  # optional release notes


@router.post("/prompts/deploy-all")
async def deploy_all_prompts(
    body: PromptDeployAllRequest,
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """
    Atomic deploy — takes ALL visible textareas from the simulator (sent as snapshot),
    writes them to .md files, and saves the entire set as one version.
    Version auto-increments: v0.0.1, v0.0.2, v0.0.3...
    """
    raise HTTPException(status_code=403, detail="Deploy feature is currently disabled.")
    from ..services.llm_service import PROMPTS_DIR
    from datetime import timezone
    import json

    # Read ALL current prompt files into a snapshot
    prompt_files = [
        "base-prompt", "profile-A0", "profile-A1", "profile-A2",
        "profile-B1", "profile-B2", "profile-C1",
        "conv-unit-framing", "conversation-prompt",
        "end-result-prompt", "placement-check-prompt",
        "correction-extraction-prompt",
    ]
    snapshot = {}
    for name in prompt_files:
        path = PROMPTS_DIR / f"{name}.md"
        if path.exists():
            snapshot[name] = path.read_text()

    # Determine next version number
    last_version_result = await db.execute(
        select(prompt_versions_table.c.version)
        .order_by(desc(prompt_versions_table.c.id))
        .limit(1)
    )
    last_row = last_version_result.fetchone()
    if last_row and last_row.version:
        # Parse v0.0.X and increment
        parts = last_row.version.lstrip("v").split(".")
        try:
            parts[-1] = str(int(parts[-1]) + 1)
            next_version = "v" + ".".join(parts)
        except ValueError:
            next_version = "v0.0.1"
    else:
        next_version = "v0.0.1"

    # Save to DB
    await db.execute(
        prompt_versions_table.insert().values(
            version=next_version,
            author=body.author,
            notes=body.notes,
            snapshot=snapshot,
            created_at=datetime.now(timezone.utc),
        )
    )
    await db.commit()

    return {
        "status": "deployed",
        "version": next_version,
        "author": body.author,
        "files_count": len(snapshot),
        "files": list(snapshot.keys()),
    }


class PromptDeploySnapshotRequest(BaseModel):
    author: str
    notes: str = ""
    snapshot: dict  # {"base-prompt": "content...", "profile-A0": "content...", ...}


@router.post("/prompts/deploy-snapshot")
async def deploy_snapshot(
    body: PromptDeploySnapshotRequest,
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """
    Deploy a snapshot to production — writes files and updates the CURRENT version.
    Does NOT auto-bump version. Multiple people can deploy iteratively on the same version.
    Contributors are accumulated. Use POST /prompts/version-bump to intentionally create a new version.
    """
    raise HTTPException(status_code=403, detail="Deploy feature is currently disabled.")
    from ..services.llm_service import PROMPTS_DIR
    from datetime import timezone

    valid_names = [
        "base-prompt", "conversation-prompt", "conv-unit-framing",
        "end-result-prompt", "placement-check-prompt",
        "correction-extraction-prompt",
        "profile-A0", "profile-A1", "profile-A2",
        "profile-B1", "profile-B2", "profile-C1",
    ]

    # Validate all keys
    for name in body.snapshot:
        if name not in valid_names:
            raise HTTPException(status_code=400, detail=f"Invalid prompt name: {name}. Valid: {valid_names}")

    # Get current (latest) version
    last_version_result = await db.execute(
        select(prompt_versions_table)
        .order_by(desc(prompt_versions_table.c.id))
        .limit(1)
    )
    last_row = last_version_result.fetchone()

    # Write files to disk
    for name, file_content in body.snapshot.items():
        target = PROMPTS_DIR / f"{name}.md"
        if target.exists():
            backup = PROMPTS_DIR / f"{name}.md.bak"
            backup.write_text(target.read_text())
        target.write_text(file_content)

    if last_row:
        # Update existing version — add contributor if new
        existing_authors = last_row.author or ""
        author_list = [a.strip() for a in existing_authors.split(",")]
        if body.author.strip() not in author_list:
            author_list.append(body.author.strip())
        new_authors = ", ".join(author_list)

        await db.execute(
            prompt_versions_table.update()
            .where(prompt_versions_table.c.id == last_row.id)
            .values(
                author=new_authors,
                snapshot=body.snapshot,
                notes=body.notes,
                created_at=datetime.now(timezone.utc),
            )
        )
        await db.commit()

        return {
            "status": "deployed",
            "version": last_row.version,
            "author": new_authors,
            "files_written": list(body.snapshot.keys()),
            "files_count": len(body.snapshot),
        }
    else:
        # No version exists yet — create v0.0.1
        await db.execute(
            prompt_versions_table.insert().values(
                version="v0.0.1",
                author=body.author,
                notes="",
                snapshot=body.snapshot,
                created_at=datetime.now(timezone.utc),
            )
        )
        await db.commit()

        return {
            "status": "deployed",
            "version": "v0.0.1",
            "author": body.author,
            "files_written": list(body.snapshot.keys()),
            "files_count": len(body.snapshot),
        }


@router.post("/prompts/version-bump")
async def bump_prompt_version(
    body: dict = None,
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """
    Intentionally bump to a new version — takes a snapshot of current production files
    and locks the current state as the next version number. Use when iteration is done.
    """
    raise HTTPException(status_code=403, detail="Deploy feature is currently disabled.")
    from ..services.llm_service import PROMPTS_DIR
    from datetime import timezone

    author = (body or {}).get("author", "(unknown)")

    # Read current prompt files
    prompt_files = [
        "base-prompt", "profile-A0", "profile-A1", "profile-A2",
        "profile-B1", "profile-B2", "profile-C1",
        "conv-unit-framing", "conversation-prompt",
        "end-result-prompt", "placement-check-prompt",
        "correction-extraction-prompt",
    ]
    snapshot = {}
    for name in prompt_files:
        path = PROMPTS_DIR / f"{name}.md"
        if path.exists():
            snapshot[name] = path.read_text()

    # Determine next version
    last_version_result = await db.execute(
        select(prompt_versions_table.c.version)
        .order_by(desc(prompt_versions_table.c.id))
        .limit(1)
    )
    last_row = last_version_result.fetchone()
    if last_row and last_row.version:
        parts = last_row.version.lstrip("v").split(".")
        try:
            parts[-1] = str(int(parts[-1]) + 1)
            next_version = "v" + ".".join(parts)
        except ValueError:
            next_version = "v0.0.1"
    else:
        next_version = "v0.0.1"

    # Create new version row
    await db.execute(
        prompt_versions_table.insert().values(
            version=next_version,
            author=author,
            notes="",
            snapshot=snapshot,
            created_at=datetime.now(timezone.utc),
        )
    )
    await db.commit()

    return {
        "status": "bumped",
        "version": next_version,
        "files_count": len(snapshot),
    }


@router.get("/prompts/versions")
async def get_prompt_versions(
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """Get all prompt versions — simple list with version, author, timestamp."""
    result = await db.execute(
        select(prompt_versions_table).order_by(desc(prompt_versions_table.c.id)).limit(50)
    )
    rows = result.fetchall()
    return [
        {
            "id": row.id,
            "version": row.version,
            "author": row.author,
            "notes": row.notes,
            "files_count": len(row.snapshot) if row.snapshot else 0,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        }
        for row in rows
    ]


@router.get("/prompts/versions/{version_id}")
async def get_prompt_version_detail(
    version_id: int,
    _: None = Depends(_check_key),
    db: AsyncSession = Depends(get_db),
):
    """Get full snapshot for a specific version — used to restore."""
    result = await db.execute(
        select(prompt_versions_table).where(prompt_versions_table.c.id == version_id)
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Version not found")
    return {
        "id": row.id,
        "version": row.version,
        "author": row.author,
        "notes": row.notes,
        "snapshot": row.snapshot,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


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
    # Targets are level-specific even when the public unit ID repeats.
    user.due_next = {}

    if body.reset_progress:
        user.skills_progress = {
            "owned": [], "emerging": [], "sightings": {},
            "strength": {}, "last_seen": {}, "effort": {"times_spoken_total": 0}
        }

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

    from sqlalchemy import delete
    from ..models.session_analysis import SessionAnalysis
    from ..models.message import Message
    from ..models.conversation import Conversation

    # Delete placements
    await db.execute(delete(Placement).where(Placement.user_id == user.id))

    # Delete conversations and related records
    conv_res = await db.execute(select(Conversation.id).where(Conversation.user_id == user.id))
    conv_ids = conv_res.scalars().all()

    if conv_ids:
        await db.execute(delete(SessionAnalysis).where(SessionAnalysis.conversation_id.in_(conv_ids)))
        await db.execute(delete(Message).where(Message.conversation_id.in_(conv_ids)))
        await db.execute(delete(Conversation).where(Conversation.id.in_(conv_ids)))


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
