import json
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm.attributes import flag_modified
from ..models.user import User
from ..models.conversation import Conversation
from ..models.session_analysis import SessionAnalysis
from ..services import llm_service
from ..core.curriculum_data import (
    CAT, UNIT_SKILLS, FLOOR,
    targets_list_for as targets_list_for_py, apply_merge, active_step,
)

async def run_and_save_session_analysis(
    conversation_id: str,
    messages: list[dict],
    topic: str,
    level: str,
    level_label: str,
    progression_model: str,
    user: User,
    db: AsyncSession,
    turns_total: int | None = None,
) -> dict:
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
    aimed = targets_list_for_py(progress, progression_model, level)
    
    if progression_model == "unit":
        emerging_unit_skills = [sid for sid in progress.get("emerging", []) if sid in UNIT_SKILLS]
        primary_ids = list(set(aimed + emerging_unit_skills))
    else:
        emerging_level_skills = [sid for sid in progress.get("emerging", []) if any(s[0] == sid and s[1] == level.upper() for s in CAT)]
        primary_ids = list(set(aimed + emerging_level_skills))

    # Run combined qualitative analysis and quantitative grading
    try:
        analysis = await llm_service.analyze_and_grade_session(
            messages=messages,
            topic=topic,
            level=level,
            level_label=level_label,
            target_skill_ids=primary_ids,
        )
        scores = analysis.get("scores", [])
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM error: {e}")

    # Apply merge & deterministic updates
    updated_progress, changes = apply_merge(progress, scores, level)
    
    # Increment times spoken
    if turns_total is not None:
        turn_count = turns_total
    else:
        turn_count = len([m for m in messages if m["role"] in ("user", "learner")])
    updated_progress["effort"]["times_spoken_total"] = updated_progress["effort"].get("times_spoken_total", 0) + turn_count
    
    # Check for unit progression level-up
    if progression_model == "unit":
        next_step = active_step(updated_progress, level)
        if next_step is None:  # Completed all units
            levels_chain = ["A1", "A2", "B1", "B2", "C1", "C2"]
            try:
                current_idx = levels_chain.index(level.upper())
                if current_idx < len(levels_chain) - 1:
                    next_lvl = levels_chain[current_idx + 1]
                    user.level = next_lvl
                    from ..core.curriculum_data import HEADLINES
                    user.level_label = HEADLINES.get(next_lvl, "Finding My Voice")
                    level = next_lvl
            except ValueError:
                pass

    # Compute next due targets
    due_next_dict = {}
    if progression_model == "unit":
        from ..core.curriculum_data import due_unit
        du = due_unit(updated_progress, level)
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

    # Check if user should advance level based on owned skills
    from ..core.curriculum_data import UNITS
    owned = updated_progress.get("owned", [])
    current_level = user.level or "A1"
    # Ensure level is always set in DB
    if not user.level:
        user.level = "A1"
    level_units = UNITS.get(current_level.upper(), [])
    if level_units:
        # All skills across all units at this level
        all_level_skills = []
        for u in level_units:
            all_level_skills.extend([s["id"] for s in u.get("skills", [])])
        # If 80%+ of level skills are owned, advance to next level
        if all_level_skills:
            owned_at_level = [s for s in owned if s in all_level_skills]
            if len(owned_at_level) >= len(all_level_skills) * 0.8:
                level_order = ["A1", "A2", "B1", "B2", "C1", "C2"]
                current_idx = level_order.index(current_level.upper()) if current_level.upper() in level_order else 0
                if current_idx < len(level_order) - 1:
                    user.level = level_order[current_idx + 1]

    # Persist qualitative and quantitative analysis
    best = analysis.get("best_moment", {})
    courage = analysis.get("courage_or_motivation", {})
    try_next = analysis.get("try_next_time", {})
    notes = analysis.get("transcript_notes", [])

    existing = await db.execute(
        select(SessionAnalysis).where(
            SessionAnalysis.conversation_id == conversation_id
        )
    )
    sa = existing.scalar_one_or_none()
    if sa is None:
        sa = SessionAnalysis(conversation_id=conversation_id)
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
    conv_result = await db.execute(
        select(Conversation).where(Conversation.id == conversation_id)
    )
    conversation = conv_result.scalar_one_or_none()
    if conversation:
        conversation.quality = analysis.get("overall")
        db.add(conversation)

    await db.flush()

    return {
        **analysis,
        "aimed_at": aimed,
        "hit_targets": hit,
        "skills_evidenced": scores,
        "state_changes": changes,
    }
