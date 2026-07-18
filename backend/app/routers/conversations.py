import json
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..models.conversation import Conversation
from ..models.message import Message
from ..models.session_analysis import SessionAnalysis
from ..schemas.conversation import (
    CreateConversationRequest, ConversationOut,
    StoreMessageRequest, MessageOut, SessionLogResponse,
    ConversationTurnRequest, ConversationTurnResponse,
)

router = APIRouter(prefix="", tags=["session"])


@router.post("", response_model=ConversationOut)
async def create_conversation(
    body: CreateConversationRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from ..services import llm_service
    from ..core.curriculum_data import (
        UNITS, LEVEL_TOPICS, targets_list_for, validate_due_next,
    )

    # Determine aimed_at skills based on active unit step
    aimed_skills = []
    level = (user.level or "A0").upper()
    units = UNITS.get(level, UNITS.get("A0", []))
    active_unit_obj = None

    if body.unit:
        for u in units:
            if u.get("name") == body.unit or str(u.get("unit")) == str(body.unit):
                active_unit_obj = u
                break

    if not active_unit_obj:
        due = validate_due_next(user.due_next, level)
        if not due:
            aimed = targets_list_for(user.skills_progress or {}, "unit", level)
            due = {"primary": aimed[0] if aimed else None}
        primary_skill_id = due.get("primary")
        if primary_skill_id:
            for u in units:
                skill_ids = [s["id"] for s in u.get("skills", [])]
                if primary_skill_id in skill_ids:
                    active_unit_obj = u
                    break

    if not active_unit_obj and units:
        active_unit_obj = units[0]

    if active_unit_obj:
        aimed_skills = [s["id"] for s in active_unit_obj.get("skills", [])]

    unit_name = active_unit_obj.get("name", "Free Talk") if active_unit_obj else "Free Talk"

    # Select a conversational topic from LEVEL_TOPICS instead of using the Unit name
    topic_name = None
    starters = None

    # Check if body.topic or body.unit is actually a topic name or topic ID
    input_topic = body.topic or body.unit
    if input_topic:
        level_topics = LEVEL_TOPICS.get(level, [])
        for t in level_topics:
            if t.get("name") == input_topic or t.get("id") == input_topic:
                topic_name = t["name"]
                starters = t.get("starters")
                break

    if not topic_name:
        import random
        level_topics = LEVEL_TOPICS.get(level, [])
        valid_topics = [t for t in level_topics if t.get("name")]
        
        persona = user.persona_memory or {}
        used_topics = persona.get("last_topics", [])
        if not isinstance(used_topics, list):
            used_topics = []
            
        fresh_topics = [t for t in valid_topics if t["name"] not in used_topics]
        pool = fresh_topics if fresh_topics else valid_topics
        
        if pool:
            selected_topic = random.choice(pool)
            topic_name = selected_topic["name"]
            starters = selected_topic.get("starters")
        else:
            topic_name = "Free Talk"

    # Generate starter using LLM
    try:
        starter_data = await llm_service.generate_conversation_starter(
            topic=topic_name,
            starters=starters,
            level=level,
            due_next=user.due_next,
            skills_progress=user.skills_progress,
            persona_memory=user.persona_memory
        )
        starter_text = starter_data["starter"]
        prompt_debug = starter_data.get("prompt_debug")
    except Exception:
        # Keep the fallback compatible with the active level profile.
        starter_text = (
            "Rice or noodles?"
            if level == "A0"
            else "What would you like to talk about today?"
        )
        prompt_debug = None

    conv = Conversation(user_id=user.id, topic=unit_name, header_title=topic_name)
    db.add(conv)
    await db.flush()

    # Save starter as the first message (Zoe's opener)
    starter_msg = Message(
        conversation_id=conv.id,
        role="assistant",
        content=starter_text,
        turn_number=0
    )
    db.add(starter_msg)
    await db.flush()

    # Determine aimed_at skills from the current unit
    aimed_at = aimed_skills if aimed_skills else []

    return _conv_out(conv, starter=starter_text, level=level, aimed_at=aimed_at, prompt_debug=prompt_debug)


@router.get("", response_model=list[ConversationOut])
async def list_conversations(
    limit: int = 20,
    offset: int = 0,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Conversation)
        .where(Conversation.user_id == user.id)
        .order_by(desc(Conversation.created_at))
        .limit(limit)
        .offset(offset)
    )
    return [_conv_out(c) for c in result.scalars().all()]


@router.get("/{session_id}", response_model=ConversationOut)
async def get_conversation(
    session_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_owned(session_id, user.id, db)
    return _conv_out(conv)




@router.post("/{session_id}/messages", response_model=MessageOut)
async def store_message(
    session_id: str,
    body: StoreMessageRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _get_owned(session_id, user.id, db)
    msg = Message(
        conversation_id=session_id,
        role=body.role,
        content=body.content,
        turn_number=body.turn_number,
    )
    db.add(msg)
    await db.flush()
    return _msg_out(msg)


@router.get("/{session_id}/messages", response_model=list[MessageOut])
async def get_messages(
    session_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _get_owned(session_id, user.id, db)
    result = await db.execute(
        select(Message)
        .where(Message.conversation_id == session_id)
        .order_by(Message.turn_number, Message.created_at)
    )
    return [_msg_out(m) for m in result.scalars().all()]


@router.get("/{session_id}/analysis")
async def get_conversation_analysis(
    session_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _get_owned(session_id, user.id, db)
    result = await db.execute(
        select(SessionAnalysis).where(
            SessionAnalysis.conversation_id == session_id
        )
    )
    analysis = result.scalar_one_or_none()
    if not analysis:
        raise HTTPException(
            status_code=404, detail="Analysis not found for this conversation"
        )
    return {
        "overall": analysis.overall,
        "best_moment": {
            "quote": analysis.best_moment_quote,
            "note": analysis.best_moment_note,
        },
        "courage_or_motivation": {
            "type": analysis.courage_type,
            "content": analysis.courage_content,
        },
        "try_next_time": {
            "skill": analysis.try_next_skill,
            "example": analysis.try_next_example,
        },
        "transcript_notes": (
            json.loads(analysis.transcript_notes_json)
            if analysis.transcript_notes_json
            else []
        ),
        "aimed_at": analysis.aimed_at or [],
        "hit_targets": analysis.hit_targets or [],
        "skills_evidenced": analysis.skills_evidenced or [],
        "state_changes": analysis.state_changes or [],
    }


@router.get("/{session_id}/session-log", response_model=SessionLogResponse)
async def get_session_log(
    session_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_owned(session_id, user.id, db)
    
    # 1. Fetch messages (transcript)
    msg_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == session_id)
        .order_by(Message.turn_number, Message.created_at)
    )
    messages_db = msg_result.scalars().all()
    transcript = [
        {"role": "zoe" if m.role in ("zoe", "assistant") else "me", "content": m.content}
        for m in messages_db
    ]
    
    # 2. Fetch SessionAnalysis
    analysis_result = await db.execute(
        select(SessionAnalysis).where(SessionAnalysis.conversation_id == session_id)
    )
    analysis = analysis_result.scalar_one_or_none()
    
    # Default progression model
    progression_model = conv.session_type or "unit"
    if progression_model not in ("unit", "skill"):
        progression_model = "unit"
        
    if not analysis:
        # Return a shell response if analysis is missing
        return SessionLogResponse(
            session_id=session_id,
            user_id=user.device_id or user.id,
            level=user.level,
            progression_model=progression_model,
            prompt_version="backend_v1",
            timestamp=conv.created_at or datetime.now(timezone.utc),
            turns_total=len([m for m in transcript if m["role"] == "me"]),
            unit=conv.topic,
            aimed_at=[],
            hit_targets=[],
            skills_evidenced=[],
            state_changes=[],
            transcript=transcript,
        )

    from ..core.curriculum_data import get_skill_text

    def get_miss_reason(confidence: float) -> str:
        if confidence >= 0.7:
            return ""
        elif confidence >= 0.3:
            return "Evidence too weak for this target; Zoe should elicit a clearer answer."
        else:
            return "No evidence found. Likely Zoe did not create a chance, learner stayed off-target, or the chat was too short."

    # Map skills evidenced
    skills_evidenced_list = []
    raw_evidenced = analysis.skills_evidenced or []
    for s in raw_evidenced:
        conf = s.get("confidence", 0.0)
        skills_evidenced_list.append({
            "id": s.get("id"),
            "name": get_skill_text(s.get("id"), user.level),
            "confidence": conf,
            "prompted": s.get("prompted", False),
            "support_level": s.get("support_level"),
            "evidence": s.get("evidence") or "",
            "reason": get_miss_reason(conf),
        })

    # Map state changes
    state_changes_list = []
    raw_changes = analysis.state_changes or []
    for c in raw_changes:
        state_changes_list.append({
            "id": c.get("id"),
            "from": c.get("from"),
            "to": c.get("to"),
            "name": get_skill_text(c.get("id"), user.level),
        })

    return SessionLogResponse(
        session_id=session_id,
        user_id=user.device_id or user.id,
        level=user.level,
        progression_model=progression_model,
        prompt_version="backend_v1",
        timestamp=conv.created_at or datetime.now(timezone.utc),
        turns_total=len([m for m in transcript if m["role"] == "me"]),
        unit=conv.topic,
        aimed_at=analysis.aimed_at or [],
        hit_targets=analysis.hit_targets or [],
        skills_evidenced=skills_evidenced_list,
        state_changes=state_changes_list,
        transcript=transcript,
    )


@router.post("/{session_id}/turn", response_model=ConversationTurnResponse)
async def conversation_turn(
    session_id: str,
    body: ConversationTurnRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    import time
    from ..services import llm_service

    # 1. Fetch and verify ownership of the conversation
    conv = await _get_owned(session_id, user.id, db)
    if conv.completed:
        raise HTTPException(status_code=400, detail="Conversation already completed")

    # 2. Fetch existing messages to calculate turn number and construct LLM history
    msg_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == session_id)
        .order_by(Message.turn_number, Message.created_at)
    )
    existing_messages = msg_result.scalars().all()
    
    # Calculate turn number for this new turn
    user_turn_number = len([m for m in existing_messages if m.role == "user"]) + 1

    # 3. Create and store user message
    user_msg = Message(
        conversation_id=session_id,
        role="user",
        content=body.content,
        turn_number=user_turn_number,
    )
    db.add(user_msg)
    await db.flush()

    # 4. Construct messages history list for LLM (existing messages + new user message)
    llm_history = [
        {"role": "assistant" if m.role in ("zoe", "assistant") else "user", "content": m.content}
        for m in existing_messages
    ] + [{"role": "user", "content": body.content}]

    # 5. Resolve user level details
    level_label_map = {
        "A0": "First Words",
        "A1": "Finding My Voice",
        "A2": "Building Confidence",
        "B1": "Expressing Myself",
        "B2": "Speaking Fluently",
        "C1": "Mastering the Language"
    }

    level_code = user.level or "A0"
    unit_label = level_label_map.get(level_code.upper(), "Finding My Voice")

    # Resolve target skills
    from ..core.curriculum_data import (
        make_due_next, targets_list_for, validate_due_next,
    )
    due_next = validate_due_next(user.due_next, level_code)
    if not due_next or not due_next.get("primary"):
        session_type = conv.session_type or "unit"
        if session_type not in ("unit", "skill"):
            session_type = "unit"
        aimed = targets_list_for(user.skills_progress or {}, session_type, level_code)
        due_next = make_due_next(aimed, level_code)

    # 6. Call LLM service to get Zoe's response
    start_time = time.time()
    try:
        llm_result = await llm_service.send_conversation_turn(
            messages=llm_history,
            topic=conv.topic or "Free conversation",
            level=level_code,
            unit_label=unit_label,
            current_turn=user_turn_number,
            persona_memory=user.persona_memory,
            due_next=due_next,
            skills_progress=user.skills_progress or {},
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM service error: {e}")
    
    llm_duration_ms = int((time.time() - start_time) * 1000)

    # 7. Save Zoe's reply to the database
    zoe_msg = Message(
        conversation_id=session_id,
        role="zoe",
        content=llm_result["reply"],
        correction=llm_result.get("correction"),
        llm_duration_ms=llm_duration_ms,
        turn_number=user_turn_number,
    )
    db.add(zoe_msg)
    
    # If the LLM indicates the conversation should complete, update conversation status
    if llm_result.get("conversation_complete"):
        conv.completed = True
        conv.completed_at = datetime.now(timezone.utc)
        
    await db.commit()
    
    # 7. Fetch full transcript to return in Response
    transcript_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == session_id)
        .order_by(Message.turn_number, Message.created_at)
    )
    db_messages = transcript_result.scalars().all()
    transcript = [
        {"role": "zoe" if m.role in ("zoe", "assistant") else "me", "content": m.content}
        for m in db_messages
    ]

    return ConversationTurnResponse(
        transcript=transcript,
        conversation_complete=conv.completed,
        prompt_debug=llm_result.get("prompt_debug"),
    )


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_owned(conv_id: str, user_id: str, db: AsyncSession) -> Conversation:
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == conv_id, Conversation.user_id == user_id
        )
    )
    conv = result.scalar_one_or_none()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conv


def _conv_out(c: Conversation, starter: str | None = None, level: str | None = None, aimed_at: list | None = None, prompt_debug: dict | None = None) -> ConversationOut:
    return ConversationOut(
        session_id=c.id,
        unit=c.topic,
        topic=c.header_title,
        starter=starter,
        level=level,
        aimed_at=aimed_at,
        completed=c.completed,
        created_at=c.created_at,
        prompt_debug=prompt_debug,
    )


def _msg_out(m: Message) -> MessageOut:
    return MessageOut(
        id=m.id,
        role=m.role,
        content=m.content,
        turn_number=m.turn_number,
        created_at=m.created_at,
    )
