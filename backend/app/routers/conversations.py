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
    CompleteConversationRequest,
    StoreMessageRequest, MessageOut,
)

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


@router.put("/{conversation_id}/complete", response_model=ConversationOut)
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
    return _conv_out(conv)


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
