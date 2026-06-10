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
    SessionAnalysisRequest,
)
from ..services import llm_service
from ..core.curriculum_data import (
    CAT, UNIT_SKILLS, FLOOR,
    targets_list_for, apply_merge, active_step,
    targets_list_for as targets_list_for_py,
)
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
            persona_memory=user.persona_memory,
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
        result = await llm_service.send_placement_turn(
            messages=messages,
            name=body.name or user.name,
            age=body.age or (int(user.age) if user.age and user.age.isdigit() else None),
        )
        return PlacementTurnResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")


@router.post("/session-analysis")
async def session_analysis(
    body: SessionAnalysisRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Performs post-session analysis on a completed conversation.
    
    - Evaluates student performance (best moments, courage highlights, try-next-time recommendations).
    - Extracts new student persona facts mentioned during the chat.
    - Idempotently merges these facts with the child's permanent database `persona_memory` profile.
    - Runs the LLM Judge to grade the conversation target skills.
    - Deterministically merges grades into the user's `skills_progress` and updates next targets.
    """
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

    level = body.level or user.level or "A1"
    model = body.progression_model

    # Initialize progress if empty
    progress = user.skills_progress or {}
    if not isinstance(progress, dict):
        progress = {}
    if "owned" not in progress: progress["owned"] = []
    if "emerging" not in progress: progress["emerging"] = []
    if "sightings" not in progress: progress["sightings"] = {}
    if "strength" not in progress: progress["strength"] = {}
    if "last_seen" not in progress: progress["last_seen"] = {}
    if "effort" not in progress: progress["effort"] = {"times_spoken_total": 0}

    # Determine targeted skills
    aimed = targets_list_for_py(progress, model, level)
    
    if model == "unit":
        emerging_unit_skills = [sid for sid in progress.get("emerging", []) if sid in UNIT_SKILLS]
        primary_ids = list(set(aimed + emerging_unit_skills))
    else:
        emerging_level_skills = [sid for sid in progress.get("emerging", []) if any(s[0] == sid and s[1] == level.upper() for s in CAT)]
        primary_ids = list(set(aimed + emerging_level_skills))

    # Run qualitative analysis and quantitative grading in parallel/sequence
    try:
        messages = [m.model_dump() for m in body.messages]
        
        # 1. Qualitative analysis (facts, best moments, courage, etc.)
        analysis = await llm_service.analyze_session(
            messages=messages,
            topic=body.topic,
            level=level,
            level_label=body.level_label,
        )
        if analysis is None:
            raise HTTPException(status_code=502, detail="Qualitative analysis failed")

        # 2. Skill scoring (LLM Judge)
        scores = await llm_service.grade_skills(
            messages=messages,
            level=level,
            target_skill_ids=primary_ids,
        )
        
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")

    # Apply merge & deterministic updates
    updated_progress, changes = apply_merge(progress, scores, level)
    
    # Increment times spoken
    turn_count = len([m for m in messages if m["role"] == "user"])
    updated_progress["effort"]["times_spoken_total"] = updated_progress["effort"].get("times_spoken_total", 0) + turn_count
    
    # Check for unit progression level-up
    if model == "unit" and level.upper() == "A1":
        next_step = active_step(updated_progress)
        if next_step is None:  # Completed all units
            user.level = "A2"
            user.level_label = "Finding My Voice"
            level = "A2"

    # Compute next due targets
    due_next_dict = {}
    if model == "unit":
        from ..core.curriculum_data import due_unit
        du = due_unit(updated_progress)
        picks = du["picks"]
    else:
        from ..core.curriculum_data import due_skill
        picks = due_skill(updated_progress, level)
        
    due_next_ids = [p["id"] for p in picks]
    due_next_dict = {
        "primary": due_next_ids[0] if due_next_ids else None,
        "watching": due_next_ids[1:] if len(due_next_ids) > 1 else []
    }

    # Save user progress & targets
    user.skills_progress = updated_progress
    user.due_next = due_next_dict
    flag_modified(user, "skills_progress")
    flag_modified(user, "due_next")

    # Persist qualitative and quantitative analysis
    best = analysis.get("best_moment", {})
    courage = analysis.get("courage_or_motivation", {})
    try_next = analysis.get("try_next_time", {})
    notes = analysis.get("transcript_notes", [])

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

    # Save grading checklist details
    hit = [sc["id"] for sc in scores if sc.get("confidence", 0.0) >= FLOOR]
    sa.aimed_at = aimed
    sa.hit_targets = hit
    sa.skills_evidenced = scores
    sa.state_changes = changes

    # Merge newly extracted memory facts
    new_facts = analysis.get("extracted_memory_facts", [])
    if isinstance(new_facts, list) and new_facts:
        existing_memory = user.persona_memory or {}
        if not isinstance(existing_memory, dict):
            existing_memory = {}
        existing_facts = existing_memory.get("facts", [])
        if not isinstance(existing_facts, list):
            existing_facts = [existing_facts] if existing_facts else []
        
        seen = {f.strip().lower() for f in existing_facts}
        merged_facts = list(existing_facts)
        for fact in new_facts:
            if isinstance(fact, str) and fact.strip() and fact.strip().lower() not in seen:
                merged_facts.append(fact.strip())
                seen.add(fact.strip().lower())
        
        existing_memory["facts"] = merged_facts
        user.persona_memory = dict(existing_memory)
        flag_modified(user, "persona_memory")
        db.add(user)

    # Update conversation quality
    conversation.quality = analysis.get("overall")
    db.add(conversation)

    await db.flush()

    # Build the combined response including grading details
    response_payload = {
        **analysis,
        "aimed_at": aimed,
        "hit_targets": hit,
        "skills_evidenced": scores,
        "state_changes": changes,
    }
    return response_payload

