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
    CompleteConversationRequest, CompleteConversationResponse,
    StoreMessageRequest, MessageOut, SessionLogResponse,
    ConversationTurnRequest, ConversationTurnResponse,
)
from .analysis_shared import run_and_save_session_analysis

router = APIRouter(prefix="/conversations", tags=["conversations"])


@router.post("", response_model=ConversationOut)
async def create_conversation(
    body: CreateConversationRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conv = Conversation(user_id=user.id, topic=body.topic)
    db.add(conv)
    await db.flush()
    return _conv_out(conv)


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


@router.get("/{conversation_id}", response_model=ConversationOut)
async def get_conversation(
    conversation_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_owned(conversation_id, user.id, db)
    return _conv_out(conv)


@router.put("/{conversation_id}/complete", response_model=CompleteConversationResponse)
async def complete_conversation(
    conversation_id: str,
    body: CompleteConversationRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_owned(conversation_id, user.id, db)
    conv.completed = True
    conv.completed_at = datetime.now(timezone.utc)
    if body.duration_seconds is not None:
        conv.duration_seconds = body.duration_seconds
    if body.session_type is not None:
        conv.session_type = body.session_type
    db.add(conv)
    await db.flush()

    analysis_out = None
    if body.run_analysis:
        # Fetch all messages for the conversation
        msg_result = await db.execute(
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.turn_number, Message.created_at)
        )
        messages_db = msg_result.scalars().all()
        messages_list = [
            {"role": "assistant" if m.role == "zoe" else "user", "content": m.content}
            for m in messages_db
        ]

        # Fallback values if level/label not passed in body
        level = body.level or user.level or "A1"
        level_label = body.level_label or user.level_label or "First Words"
        topic = conv.topic or "Free Talk"

        # Run combined analysis and grading
        analysis_out = await run_and_save_session_analysis(
            conversation_id=conversation_id,
            messages=messages_list,
            topic=topic,
            level=level,
            level_label=level_label,
            progression_model=body.progression_model,
            user=user,
            db=db,
        )

    return CompleteConversationResponse(
        conversation=_conv_out(conv),
        analysis=analysis_out
    )


@router.post("/{conversation_id}/messages", response_model=MessageOut)
async def store_message(
    conversation_id: str,
    body: StoreMessageRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _get_owned(conversation_id, user.id, db)
    msg = Message(
        conversation_id=conversation_id,
        role=body.role,
        content=body.content,
        correction=body.correction,
        stt_duration_ms=body.stt_duration_ms,
        llm_duration_ms=body.llm_duration_ms,
        tts_duration_ms=body.tts_duration_ms,
        turn_number=body.turn_number,
    )
    db.add(msg)
    await db.flush()
    return _msg_out(msg)


@router.get("/{conversation_id}/messages", response_model=list[MessageOut])
async def get_messages(
    conversation_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _get_owned(conversation_id, user.id, db)
    result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.turn_number, Message.created_at)
    )
    return [_msg_out(m) for m in result.scalars().all()]


@router.get("/{conversation_id}/analysis")
async def get_conversation_analysis(
    conversation_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _get_owned(conversation_id, user.id, db)
    result = await db.execute(
        select(SessionAnalysis).where(
            SessionAnalysis.conversation_id == conversation_id
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


@router.get("/{conversation_id}/session-log", response_model=SessionLogResponse)
async def get_session_log(
    conversation_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_owned(conversation_id, user.id, db)
    
    # 1. Fetch messages (transcript)
    msg_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.turn_number, Message.created_at)
    )
    messages_db = msg_result.scalars().all()
    transcript = [
        {"speaker": "zoe" if m.role == "zoe" else "learner", "text": m.content}
        for m in messages_db
    ]
    
    # 2. Fetch SessionAnalysis
    analysis_result = await db.execute(
        select(SessionAnalysis).where(SessionAnalysis.conversation_id == conversation_id)
    )
    analysis = analysis_result.scalar_one_or_none()
    
    # Default progression model
    progression_model = conv.session_type or "unit"
    if progression_model not in ("unit", "skill"):
        progression_model = "unit"
        
    if not analysis:
        # Return a shell response if analysis is missing
        return SessionLogResponse(
            session_id=conversation_id,
            child_id=user.device_id or user.id,
            level=user.level,
            progression_model=progression_model,
            prompt_version="backend_v1",
            timestamp=conv.created_at or datetime.now(timezone.utc),
            turns_total=len([m for m in transcript if m["speaker"] == "learner"]),
            topic=conv.topic,
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
            "name": get_skill_text(s.get("id")),
            "confidence": conf,
            "prompted": s.get("prompted", False),
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
            "name": get_skill_text(c.get("id")),
        })

    return SessionLogResponse(
        session_id=conversation_id,
        child_id=user.device_id or user.id,
        level=user.level,
        progression_model=progression_model,
        prompt_version="backend_v1",
        timestamp=conv.created_at or datetime.now(timezone.utc),
        turns_total=len([m for m in transcript if m["speaker"] == "learner"]),
        topic=conv.topic,
        aimed_at=analysis.aimed_at or [],
        hit_targets=analysis.hit_targets or [],
        skills_evidenced=skills_evidenced_list,
        state_changes=state_changes_list,
        transcript=transcript,
    )


@router.post("/{conversation_id}/turn", response_model=ConversationTurnResponse)
async def conversation_turn(
    conversation_id: str,
    body: ConversationTurnRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    import time
    from ..services import llm_service

    # 1. Fetch and verify ownership of the conversation
    conv = await _get_owned(conversation_id, user.id, db)
    if conv.completed:
        raise HTTPException(status_code=400, detail="Conversation already completed")

    # 2. Fetch existing messages to calculate turn number and construct LLM history
    msg_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.turn_number, Message.created_at)
    )
    existing_messages = msg_result.scalars().all()
    
    # Calculate turn number for this new turn
    user_turn_number = len([m for m in existing_messages if m.role == "user"]) + 1

    # 3. Create and store user message
    user_msg = Message(
        conversation_id=conversation_id,
        role="user",
        content=body.content,
        stt_duration_ms=body.stt_duration_ms,
        turn_number=user_turn_number,
    )
    db.add(user_msg)
    await db.flush()

    # 4. Construct messages history list for LLM (existing messages + new user message)
    llm_history = [
        {"role": "assistant" if m.role == "zoe" else "user", "content": m.content}
        for m in existing_messages
    ] + [{"role": "user", "content": body.content}]

    # 5. Resolve user level details
    level_label_map = {
        "A1": "First Words",
        "A2": "Finding My Voice",
        "B1": "Building Confidence",
        "B2": "Expressing Myself",
        "C1": "Speaking Fluently",
        "C2": "Mastering the Language"
    }
    level_code = user.level or "A1"
    level_label = level_label_map.get(level_code.upper(), "Finding My Voice")

    # 6. Call LLM service to get Zoe's response
    start_time = time.time()
    try:
        llm_result = await llm_service.send_conversation_turn(
            messages=llm_history,
            topic=conv.topic or "Free conversation",
            level=level_code,
            level_label=level_label,
            current_turn=user_turn_number,
            persona_memory=user.persona_memory,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM service error: {e}")
    
    llm_duration_ms = int((time.time() - start_time) * 1000)

    # 7. Save Zoe's reply to the database
    zoe_msg = Message(
        conversation_id=conversation_id,
        role="zoe",
        content=llm_result["reply"],
        correction=llm_result.get("correction"),
        llm_duration_ms=llm_duration_ms,
        tts_duration_ms=body.tts_duration_ms,
        turn_number=user_turn_number,
    )
    db.add(zoe_msg)
    
    # If the LLM indicates the conversation should complete, update conversation status
    if llm_result.get("conversation_complete"):
        conv.completed = True
        conv.completed_at = datetime.now(timezone.utc)
        
    await db.commit()
    await db.refresh(user_msg)
    await db.refresh(zoe_msg)

    return ConversationTurnResponse(
        user_message=_msg_out(user_msg),
        zoe_message=_msg_out(zoe_msg),
        conversation_complete=conv.completed,
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


def _conv_out(c: Conversation) -> ConversationOut:
    return ConversationOut(
        id=c.id,
        topic=c.topic,
        header_title=c.header_title,
        duration_seconds=c.duration_seconds,
        session_type=c.session_type,
        quality=c.quality,
        completed=c.completed,
        created_at=c.created_at,
    )


def _msg_out(m: Message) -> MessageOut:
    return MessageOut(
        id=m.id,
        role=m.role,
        content=m.content,
        correction=m.correction,
        stt_duration_ms=m.stt_duration_ms,
        llm_duration_ms=m.llm_duration_ms,
        tts_duration_ms=m.tts_duration_ms,
        turn_number=m.turn_number,
        created_at=m.created_at,
    )
