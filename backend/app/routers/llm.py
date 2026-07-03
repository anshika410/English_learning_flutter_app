from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm.attributes import flag_modified
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..models.conversation import Conversation
from ..models.session_analysis import SessionAnalysis
from ..schemas.llm import (
    StarterRequest, StarterResponse,
    ConversationTurnRequest, ConversationTurnResponse,
    PlacementTurnRequest, PlacementTurnResponse,
    SessionAnalysisRequest, SessionAnalysisResponse,
)
from ..services import llm_service
from .analysis_shared import run_and_save_session_analysis
import json

router = APIRouter(prefix="/llm", tags=["llm"])


@router.post("/conversation-starter", response_model=StarterResponse)
async def conversation_starter(
    body: StarterRequest,
    user: User = Depends(get_current_user),
):
    """
    Generates a friendly opening question/starter from the AI tutor matching a selected topic.
    
    Acts as a proxy call to the LLM (DeepSeek) using prompt rendering configured server-side.
    """
    try:
        result = await llm_service.generate_conversation_starter(body.unit)
        return StarterResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")


@router.post("/conversation-turn", response_model=ConversationTurnResponse)
async def conversation_turn(
    body: ConversationTurnRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Handles turn-by-turn logic during an active topic-based conversation session.
    
    - Validates that the conversation session exists and belongs to the authenticated user.
    - Sends the dialogue history to the LLM backend proxy.
    - Applies custom coaching metrics (grammar, vocabulary, and fluency settings).
    - Returns Zoe's next spoken reply alongside immediate grammar corrections.
    """
    # Verify conversation belongs to this user
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == body.session_id,
            Conversation.user_id == user.id,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Conversation not found")

    try:
        messages = [m.model_dump() for m in body.messages]
        result = await llm_service.send_conversation_turn(
            messages=messages,
            topic=body.unit or "Free conversation",
            level=body.level,
            unit_label=body.unit_label,
            current_turn=body.current_turn,
            persona_memory=user.persona_memory,
        )
        return ConversationTurnResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")


@router.post("/placement-turn", response_model=PlacementTurnResponse)
async def placement_turn(
    body: PlacementTurnRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Executes a dialogue turn during the voice placement screening test.
    
    - Accepts the running transcript log.
    - Queries the backend LLM state machine to decide if the test should continue or complete.
    - Returns Zoe's next question OR a final CEFR assessment (`is_complete: true`) once enough evidence is gathered.
    """
    try:
        messages = [m.model_dump() for m in body.messages]
        result = await llm_service.send_placement_turn(
            messages=messages,
            name=body.name or user.name,
            age=body.age or (int(user.age) if user.age and user.age.isdigit() else None),
        )
        
        if result.get("is_complete"):
            from ..models.placement import Placement
            import json
            
            level = result.get("level")
            unit_name = result.get("unit_name")
            interests = result.get("interests", [])
            
            placement = Placement(
                user_id=user.id,
                level=level,
                unit_label=unit_name,
                confidence=result.get("confidence"),
                highlight=result.get("evidence_summary"),
                transcript_json=json.dumps(messages) if messages else None,
            )
            db.add(placement)
            
            user.level = level
            user.unit_label = unit_name
            if interests:
                user.interests = ",".join(interests)
            db.add(user)
            await db.flush()
            
        return PlacementTurnResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")


@router.post("/judge", response_model=SessionAnalysisResponse)
@router.post("/session-analysis", response_model=SessionAnalysisResponse)
async def session_analysis(
    body: SessionAnalysisRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Performs post-session analysis on a completed conversation.
    
    - Marks the conversation as completed in the database.
    - Evaluates student performance (best moments, courage highlights, try-next-time recommendations).
    - Extracts new student persona facts mentioned during the chat.
    - Idempotently merges these facts with the child's permanent database `persona_memory` profile.
    - Runs the LLM Judge to grade the conversation target skills.
    - Deterministically merges grades into the user's `skills_progress` and updates next targets.
    """
    # Verify conversation belongs to this user
    conv_result = await db.execute(
        select(Conversation).where(
            Conversation.id == body.session_id,
            Conversation.user_id == user.id,
        )
    )
    conversation = conv_result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")

    # Update completion status and metadata (automatically calculate duration from turns_total if provided)
    from datetime import datetime, timezone
    conversation.completed = True
    conversation.completed_at = datetime.now(timezone.utc)
    turns = body.turns_total if body.turns_total is not None else len([m for m in body.messages if m.role in ("user", "learner")])
    conversation.duration_seconds = turns * 30
    if body.session_type is not None:
        conversation.session_type = body.session_type
    db.add(conversation)

    level = body.level or user.level or "A0"
    messages = [m.model_dump() for m in body.messages]
    
    # Use the conversation's stored topic (set from due_next at creation time)
    # rather than trusting the client-sent topic which may be stale
    topic = conversation.topic or body.unit

    analysis_out = await run_and_save_session_analysis(
        conversation_id=body.session_id,
        messages=messages,
        topic=topic,
        level=level,
        unit_label=body.unit_label,
        progression_model=body.progression_model,
        user=user,
        db=db,
        turns_total=body.turns_total,
    )
    
    return SessionAnalysisResponse(**analysis_out)
