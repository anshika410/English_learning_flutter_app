from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..models.conversation import Conversation
from ..models.session_analysis import SessionAnalysis
from ..schemas.llm import (
    StarterRequest, StarterResponse,
    ConversationTurnRequest, ConversationTurnResponse,
    PlacementTurnRequest, PlacementTurnResponse,
    SessionAnalysisRequest,
)
from ..services import llm_service
import json

router = APIRouter(prefix="/llm", tags=["llm"])


@router.post("/conversation-starter", response_model=StarterResponse)
async def conversation_starter(
    body: StarterRequest,
    user: User = Depends(get_current_user),
):
    try:
        result = await llm_service.generate_conversation_starter(body.topic)
        return StarterResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")


@router.post("/conversation-turn", response_model=ConversationTurnResponse)
async def conversation_turn(
    body: ConversationTurnRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify conversation belongs to this user
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == body.conversation_id,
            Conversation.user_id == user.id,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Conversation not found")

    try:
        messages = [m.model_dump() for m in body.messages]
        result = await llm_service.send_conversation_turn(
            messages=messages,
            topic=body.topic or "Free conversation",
            level=body.level,
            level_label=body.level_label,
            current_turn=body.current_turn,
            grammar_focus=body.grammar_focus,
            vocab_focus=body.vocab_focus,
            fluency_focus=body.fluency_focus,
        )
        return ConversationTurnResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")


@router.post("/placement-turn", response_model=PlacementTurnResponse)
async def placement_turn(
    body: PlacementTurnRequest,
    user: User = Depends(get_current_user),
):
    try:
        messages = [m.model_dump() for m in body.messages]
        result = await llm_service.send_placement_turn(messages)
        return PlacementTurnResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")


@router.post("/session-analysis")
async def session_analysis(
    body: SessionAnalysisRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify conversation belongs to this user
    conv_result = await db.execute(
        select(Conversation).where(
            Conversation.id == body.conversation_id,
            Conversation.user_id == user.id,
        )
    )
    conversation = conv_result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")

    try:
        messages = [m.model_dump() for m in body.messages]
        analysis = await llm_service.analyze_session(
            messages=messages,
            topic=body.topic,
            level=body.level,
            level_label=body.level_label,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")

    if analysis is None:
        raise HTTPException(status_code=502, detail="Analysis failed")

    # Persist analysis
    best = analysis.get("best_moment", {})
    courage = analysis.get("courage_or_motivation", {})
    try_next = analysis.get("try_next_time", {})
    notes = analysis.get("transcript_notes", [])

    # Upsert — replace if already exists for this conversation
    existing = await db.execute(
        select(SessionAnalysis).where(
            SessionAnalysis.conversation_id == body.conversation_id
        )
    )
    sa = existing.scalar_one_or_none()
    if sa is None:
        sa = SessionAnalysis(conversation_id=body.conversation_id)
        db.add(sa)

    sa.overall = analysis.get("overall", "okay")
    sa.best_moment_quote = best.get("quote")
    sa.best_moment_note = best.get("note")
    sa.courage_type = courage.get("type")
    sa.courage_content = courage.get("content")
    sa.try_next_skill = try_next.get("skill")
    sa.try_next_example = try_next.get("example")
    sa.transcript_notes_json = json.dumps(notes)

    # Update conversation quality
    conversation.quality = analysis.get("overall")
    db.add(conversation)

    await db.flush()
    return analysis
