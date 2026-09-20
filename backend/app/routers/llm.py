from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from sqlalchemy.orm.attributes import flag_modified
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..models.conversation import Conversation
from ..models.message import Message
from ..models.session_analysis import SessionAnalysis
from ..schemas.llm import (
    StarterRequest, StarterResponse,
    ConversationTurnRequest, ConversationTurnResponse,
    PlacementTurnRequest, PlacementV2TurnRequest, PlacementTurnResponse,
    SessionAnalysisRequest, SessionAnalysisResponse,
)
from ..services import llm_service
from .analysis_shared import run_and_save_session_analysis
import json

router = APIRouter(prefix="/llm", tags=["llm"])
llm_v2_router = APIRouter(prefix="/v2/llm", tags=["llm-v2"])


def _backfill_owned_skills(user: User, placed_level: str | None):
    """Auto-unlocks all skills for CEFR levels below the placed level."""
    if not placed_level:
        return
    from ..core.curriculum_data import UNITS, unit_progress_key
    from sqlalchemy.orm.attributes import flag_modified

    LEVEL_ORDER = ["A0", "A1", "A2", "B1", "B2", "C1"]
    placed_lvl = placed_level.upper()
    if placed_lvl in LEVEL_ORDER:
        placed_idx = LEVEL_ORDER.index(placed_lvl)
        levels_to_backfill = LEVEL_ORDER[:placed_idx]

        progress = user.skills_progress or {}
        if not isinstance(progress, dict):
            progress = {}
        if "owned" not in progress:
            progress["owned"] = []
        if "emerging" not in progress:
            progress["emerging"] = []
        if "sightings" not in progress:
            progress["sightings"] = {}
        if "strength" not in progress:
            progress["strength"] = {}
        if "last_seen" not in progress:
            progress["last_seen"] = {}
        if "effort" not in progress:
            progress["effort"] = {"times_spoken_total": 0}

        from datetime import datetime, timezone
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        for lvl in levels_to_backfill:
            for unit in UNITS.get(lvl, []):
                for skill in unit.get("skills", []):
                    sid = unit_progress_key(lvl, skill["id"])
                    if not sid:
                        continue
                    if sid not in progress["owned"]:
                        progress["owned"].append(sid)
                    if sid in progress["emerging"]:
                        progress["emerging"].remove(sid)
                    if sid not in progress["sightings"]:
                        progress["sightings"][sid] = 3
                    if sid not in progress["last_seen"]:
                        progress["last_seen"][sid] = today

        user.skills_progress = progress
        flag_modified(user, "skills_progress")


def _generate_placement_recap(result: dict) -> str | None:
    """Generate a friendly recap from placement result data (interests, notes)."""
    interests = result.get("interests", [])
    notes = result.get("notes_for_first_session", "")
    
    if interests and len(interests) > 0:
        if len(interests) == 1:
            return f"You told me you like {interests[0]}!"
        elif len(interests) == 2:
            return f"You told me you like {interests[0]} and {interests[1]}!"
        else:
            return f"You told me you like {interests[0]}, {interests[1]}, and more!"
    
    if notes:
        # Try to extract something personal from the notes
        return "It was great chatting with you! Let's talk more soon."
    
    return None


async def _fetch_last_conversation_transcript(
    db: AsyncSession, user_id: str, exclude_session_id: str | None = None
) -> str | None:
    """Full turn-by-turn transcript of the user's most recently completed conversation."""
    query = select(Conversation).where(
        Conversation.user_id == user_id,
        Conversation.completed == True,  # noqa: E712
    )
    if exclude_session_id:
        query = query.where(Conversation.id != exclude_session_id)
    query = query.order_by(desc(Conversation.completed_at)).limit(1)

    result = await db.execute(query)
    last_conv = result.scalar_one_or_none()
    if not last_conv:
        return None

    msg_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == last_conv.id)
        .order_by(Message.turn_number, Message.created_at)
    )
    messages = msg_result.scalars().all()
    if not messages:
        return None

    return "\n".join(f"{m.role}: {m.content}" for m in messages)


@router.post("/conversation-starter", response_model=StarterResponse)
async def conversation_starter(
    body: StarterRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Generates a friendly opening question/starter from the AI tutor matching a selected topic.

    Acts as a proxy call to the LLM (DeepSeek) using prompt rendering configured server-side.
    """
    try:
        last_conversation_transcript = await _fetch_last_conversation_transcript(db, user.id)
        result = await llm_service.generate_conversation_starter(
            body.unit,
            level=user.level or "A1",
            user_id=f"{user.id}:{user.email}" if user.email else user.id,
            last_conversation_transcript=last_conversation_transcript,
        )
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
        last_conversation_transcript = await _fetch_last_conversation_transcript(
            db, user.id, exclude_session_id=body.session_id
        )
        result = await llm_service.send_conversation_turn(
            messages=messages,
            topic=body.unit or "Free conversation",
            level=user.level or body.level,
            unit_label=body.unit_label,
            current_turn=body.current_turn,
            persona_memory=user.persona_memory,
            due_next=user.due_next,
            skills_progress=user.skills_progress or {},
            user_id=f"{user.id}:{user.email}" if user.email else user.id,
            last_conversation_transcript=last_conversation_transcript,
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
    - If cancel=true, records cancellation without assigning a level.
    - Queries the backend LLM state machine to decide if the test should continue or complete.
    - Returns Zoe's next question OR a final CEFR assessment (`is_complete: true`) once enough evidence is gathered.
    """
    # Extract first name
    raw_name = body.name or user.name
    first_name = raw_name.strip().split(" ")[0] if raw_name else None

    # Handle cancellation
    if body.cancel:
        return PlacementTurnResponse(
            reply=None,
            is_complete=True,
            name=first_name,
            age=body.age,
            level=None,
            unit_name=None,
            level_description="Placement cancelled. You can retake anytime.",
            confidence=None,
            possible_higher=None,
            evidence_summary="Placement cancelled by user.",
            probe_targets_covered=None,
            turns_taken=len([m for m in body.messages if m.role == "user"]),
            code_switch_observed=None,
            interests=None,
            notes_for_first_session=None,
        )

    try:
        messages = [m.model_dump() for m in body.messages]
        result = await llm_service.send_placement_turn(
            messages=messages,
            name=first_name,
            age=body.age or (int(user.age) if user.age and user.age.isdigit() else None),
            custom_prompts=body.custom_prompts,
            user_id=f"{user.id}:{user.email}" if user.email else user.id,
        )
        
        # Ensure the first name is in the result so PlacementTurnResponse includes it
        result["name"] = first_name
        
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
                highlight=result.get("zoe_recap") or _generate_placement_recap(result) or result.get("evidence_summary"),
                transcript_json=json.dumps(messages) if messages else None,
            )
            db.add(placement)
            
            user.level = level
            user.unit_label = unit_name
            user.due_next = {}
            from sqlalchemy.orm.attributes import flag_modified
            flag_modified(user, "due_next")
            # Backfill lower level skills
            _backfill_owned_skills(user, level)
            if not user.first_session_done:
                user.first_session_done = True

            db.add(user)
            await db.flush()
            
        return PlacementTurnResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")


@llm_v2_router.post("/placement-turn", response_model=PlacementTurnResponse)
@router.post("/v2/placement-turn", response_model=PlacementTurnResponse)
@router.post("/placement-turn-v2", response_model=PlacementTurnResponse)
async def placement_v2_turn(
    body: PlacementV2TurnRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Executes a dialogue turn or final evaluation during the streamlined 7-step placement test (v2).
    
    - Supports sending individual turns or evaluating all captured answers at once.
    - If cancel=true, records cancellation without assigning a level.
    - Turn 0: Prompts with Question 1 ("What do you want to improve in your English?")
    - Turn 1: Prompts with Question 2 ("Tell me something about yourself?")
    - Turn 2+: Evaluates transcripts + self-reported level, returns final CEFR level & label,
      persists Placement in database, updates User profile, and unlocks prerequisite skills.
    """
    raw_name = body.name or user.name
    first_name = raw_name.strip().split(" ")[0] if raw_name else None
    age_val = body.age or (int(user.age) if user.age and user.age.isdigit() else None)

    # If new name/age are passed, update user record
    if body.name and body.name != user.name:
        user.name = body.name
        db.add(user)
    if body.age and str(body.age) != str(user.age):
        user.age = str(body.age)
        db.add(user)

    if body.cancel:
        return PlacementTurnResponse(
            reply=None,
            is_complete=True,
            name=first_name,
            age=age_val,
            level=None,
            unit_name=None,
            level_description="Placement cancelled. You can retake anytime.",
            confidence=None,
            possible_higher=None,
            evidence_summary="Placement cancelled by user.",
            probe_targets_covered=None,
            turns_taken=len([m for m in body.messages if m.role in ("user", "learner")]),
            code_switch_observed=None,
            interests=None,
            notes_for_first_session=None,
        )

    try:
        messages = [m.model_dump() for m in body.messages]
        result = await llm_service.send_placement_v2_turn(
            messages=messages,
            name=first_name,
            age=age_val,
            self_reported_level=body.self_reported_level,
            custom_prompts=body.custom_prompts,
            user_id=f"{user.id}:{user.email}" if user.email else user.id,
        )

        result["name"] = first_name
        result["age"] = age_val

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
                highlight=result.get("zoe_recap") or _generate_placement_recap(result) or result.get("evidence_summary"),
                transcript_json=json.dumps(messages) if messages else None,
            )
            db.add(placement)

            user.level = level
            user.unit_label = unit_name
            user.due_next = {}
            from sqlalchemy.orm.attributes import flag_modified
            flag_modified(user, "due_next")
            if interests:
                user.interests = ",".join(interests)

            _backfill_owned_skills(user, level)

            if not user.first_session_done:
                user.first_session_done = True

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

    level = user.level or body.level or "A0"
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
        custom_prompts=body.custom_prompts,
    )
    
    return SessionAnalysisResponse(**analysis_out)
