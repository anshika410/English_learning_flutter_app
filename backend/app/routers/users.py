from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..schemas.user import UpdateProfileRequest, UpdateMemoryRequest, UserMemoryResponse, GardenResponse, TopicResponse
from ..core.curriculum_data import UNITS, active_step, unit_complete, bucket_of


router = APIRouter(prefix="/users", tags=["users"])


def _to_memory_response(user: User) -> UserMemoryResponse:
    persona = user.persona_memory or {}
    progress = user.skills_progress or {}
    due = user.due_next or {}
    units_list = persona.get("units") or persona.get("last_topics", [])
    if not isinstance(units_list, list):
        units_list = []

    # Cast age to integer if it is a numeric string
    age_val = None
    if user.age and user.age.isdigit():
        age_val = int(user.age)

    profile_data = {
        "name": user.name or None,
        "age": age_val,
        "city": user.location or None,
        "grade": None
    }

    return UserMemoryResponse(
        id=user.id,
        device_id=user.device_id,
        profile=profile_data,
        level=user.level,
        first_session_done=user.first_session_done,
        interests=user.interests.split(",") if user.interests else [],
        owned=progress.get("owned", []),
        emerging=progress.get("emerging", []),
        due_next=due,
        effort=progress.get("effort", {"times_spoken_total": 0}),
        sightings=progress.get("sightings", {}),
        strength=progress.get("strength", {}),
        updated_after_chat=progress.get("updated_after_chat", 0),
        units=units_list,
        last_topics=units_list,
        persona_memory={k: v for k, v in (user.persona_memory or {}).items() if k not in ("last_topics", "units")},
    )


@router.get("/me", response_model=UserMemoryResponse)
async def get_profile(user: User = Depends(get_current_user)):
    return _to_memory_response(user)


@router.put("/me", response_model=UserMemoryResponse)
async def update_profile(
    body: UpdateProfileRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.name is not None:
        user.name = body.name
    if body.age is not None:
        user.age = body.age
    if body.location is not None:
        user.location = body.location
    if body.level is not None:
        user.level = body.level
    if body.level_label is not None:
        user.level_label = body.level_label
    db.add(user)
    await db.flush()
    return _to_memory_response(user)


@router.get("/me/memory", response_model=UserMemoryResponse)
async def get_user_memory(
    user: User = Depends(get_current_user)
):
    """
    Returns the student's full learning memory as a unified object.
    Combines profile, persona facts, skills progress, and next targets.
    """
    return _to_memory_response(user)


@router.put("/me/memory")
async def update_user_memory(
    body: UpdateMemoryRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Manually updates, overrides, or clears the child's permanent persona memory block.
    
    Used to modify narrative facts or clear stored memory to reset the learning context.
    """
    user.persona_memory = body.persona_memory
    db.add(user)
    await db.flush()
    return {"persona_memory": user.persona_memory}


@router.get("/me/garden", response_model=GardenResponse)
async def get_user_garden(user: User = Depends(get_current_user)):
    level = user.level or "A1"
    progress = user.skills_progress or {}
    
    units_list = UNITS.get(level.upper(), [])
    
    # Find the first unowned skill across all steps to use as a recommended fallback target
    first_unowned_skill = None
    for u in units_list:
        for s in u["skills"]:
            if bucket_of(progress, s["id"]) != "owned":
                first_unowned_skill = s["id"]
                break
        if first_unowned_skill:
            break
    if not first_unowned_skill and units_list and units_list[0]["skills"]:
        first_unowned_skill = units_list[0]["skills"][0]["id"]
    
    units_data = []
    for u in units_list:
        skills_data = []
        
        for s in u["skills"]:
            status = bucket_of(progress, s["id"])
            sightings = progress.get("sightings", {}).get(s["id"], 0)
            last_tested_at = progress.get("last_seen", {}).get(s["id"], None)
            raw_evidence = progress.get("evidence", {}).get(s["id"], [])
            evidence_list = []
            for ev in raw_evidence:
                if isinstance(ev, dict):
                    evidence_list.append({
                        "evidence": ev.get("evidence", ""),
                        "confidence": ev.get("confidence", 1.0),
                        "prompted": ev.get("prompted", False),
                        "topic": ev.get("topic", "General Conversation"),
                        "created_at": ev.get("created_at", None)
                    })
                elif isinstance(ev, str):
                    evidence_list.append({
                        "evidence": ev,
                        "confidence": 1.0,
                        "prompted": False,
                        "topic": "General Conversation",
                        "created_at": None
                    })
            
            skills_data.append({
                "id": s["id"],
                "strand": s["strand"],
                "text": s["text"],
                "status": status,
                "sightings": sightings,
                "last_tested_at": last_tested_at,
                "evidence": evidence_list
            })
            
        units_data.append({
          "unit": int(u["step"]),
          "name": u["name"],
          "focus": u["focus"],
          "skills": skills_data
        })
        
    # Resolve dynamic recommended topic based on active target skill
    due_next = user.due_next or {}
    primary_skill = due_next.get("primary") or first_unowned_skill
 
    recommended_topic = "Today, I wanted to talk about cricket. Shall we?"
    if primary_skill:
        from ..core.curriculum_data import get_elicitation_plan_for
        try:
            plan = get_elicitation_plan_for(primary_skill)
            if plan and plan.get("question"):
                recommended_topic = plan["question"]
        except Exception:
            pass
 
    return {
        "level": level,
        "recommended_topic": recommended_topic,
        "units": units_data
    }


@router.get("/me/topics", response_model=list[TopicResponse])
async def get_user_topics(user: User = Depends(get_current_user)):
    level = (user.level or "A1").upper()
    from ..core.curriculum_data import LEVEL_TOPICS
    return LEVEL_TOPICS.get(level, [])



