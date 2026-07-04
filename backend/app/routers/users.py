from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..schemas.user import UpdateProfileRequest, UpdateMemoryRequest, UserMemoryResponse, GardenResponse, TopicResponse, PlacementSubResponse
from ..core.curriculum_data import UNITS, active_step, unit_complete, bucket_of


router = APIRouter(prefix="/users", tags=["users"])


def _to_memory_response(user: User, last_time_recap: str | None = None) -> UserMemoryResponse:
    persona = user.persona_memory or {}
    progress = user.skills_progress or {}
    due = user.due_next or {}
    units_list = persona.get("units", [])
    if not isinstance(units_list, list):
        units_list = []

    last_topics_list = persona.get("last_topics", [])
    if not isinstance(last_topics_list, list):
        last_topics_list = []

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

    placement_data = None
    if user.placements:
        latest_placement = sorted(user.placements, key=lambda p: p.created_at, reverse=True)[0]
        placement_data = PlacementSubResponse(
            level=latest_placement.level,
            unit_label=latest_placement.unit_label,
            confidence=latest_placement.confidence,
            highlight=latest_placement.highlight,
            created_at=latest_placement.created_at.isoformat(),
        )

    # Compute suggested next topics (avoid recently used)
    from ..core.curriculum_data import LEVEL_TOPICS
    level_code = (user.level or "A0").upper()
    all_topics = LEVEL_TOPICS.get(level_code, [])
    valid_topics = [t for t in all_topics if t.get("name")]
    used = set(last_topics_list)
    fresh = [t["name"] for t in valid_topics if t["name"] not in used]
    if not fresh:
        fresh = [t["name"] for t in valid_topics]
    import random
    random.shuffle(fresh)
    recommended = fresh[0] if fresh else None
    alternatives = fresh[1:4] if len(fresh) > 1 else []

    from ..schemas.user import NextTopics
    next_topics_obj = NextTopics(recommended=recommended, alternatives=alternatives) if recommended else None

    return UserMemoryResponse(
        id=user.id,
        device_id=user.device_id,
        profile=profile_data,
        level=user.level,
        first_session_done=user.first_session_done,
        interests=user.interests.split(",") if user.interests else [],
        last_time_recap=last_time_recap,
        placement=placement_data,
        owned=progress.get("owned", []),
        emerging=progress.get("emerging", []),
        due_next=due,
        next_topics=next_topics_obj,
        effort=progress.get("effort", {"times_spoken_total": 0}),
        sightings=progress.get("sightings", {}),
        strength=progress.get("strength", {}),
        updated_after_chat=progress.get("updated_after_chat", 0),
        units=units_list,
        last_topics=last_topics_list,
        persona_memory={k: v for k, v in (user.persona_memory or {}).items() if k not in ("last_topics", "units")},
    )


async def _get_last_time_recap(user_id: str, db: AsyncSession) -> str | None:
    from ..models.conversation import Conversation
    from ..models.session_analysis import SessionAnalysis
    from sqlalchemy import select, desc
    try:
        conv_result = await db.execute(
            select(Conversation)
            .where(Conversation.user_id == user_id, Conversation.completed == True)
            .order_by(desc(Conversation.created_at))
            .limit(1)
        )
        latest_conv = conv_result.scalar_one_or_none()
        if latest_conv:
            sa_result = await db.execute(
                select(SessionAnalysis).where(SessionAnalysis.conversation_id == latest_conv.id)
            )
            sa = sa_result.scalar_one_or_none()
            if sa:
                return sa.zoe_recap
    except Exception:
        pass
    return None


@router.get("/me", response_model=UserMemoryResponse)
async def get_profile(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    recap = await _get_last_time_recap(user.id, db)
    return _to_memory_response(user, recap)


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
    
    unit_val = body.unit or body.unit_label
    if unit_val is not None:
        user.unit_label = unit_val
        
    db.add(user)
    await db.flush()
    recap = await _get_last_time_recap(user.id, db)
    return _to_memory_response(user, recap)


@router.get("/me/memory", response_model=UserMemoryResponse)
async def get_user_memory(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns the student's full learning memory as a unified object.
    Combines profile, persona facts, skills progress, and next targets.
    """
    recap = await _get_last_time_recap(user.id, db)
    return _to_memory_response(user, recap)


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
    level = user.level or "A0"
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
    level = (user.level or "A0").upper()
    from ..core.curriculum_data import LEVEL_TOPICS
    return LEVEL_TOPICS.get(level, [])


from pydantic import BaseModel

class PrimaryTargetResponse(BaseModel):
    id: str | None = None
    text: str | None = None

@router.get("/me/primary-target", response_model=PrimaryTargetResponse)
async def get_primary_target(user: User = Depends(get_current_user)):
    """
    Returns the student's current primary target ID and its text description.
    """
    due = user.due_next or {}
    primary_id = due.get("primary")
    
    if not primary_id:
        return PrimaryTargetResponse(id=None, text=None)
        
    from ..core.curriculum_data import get_skill_text
    skill_text = get_skill_text(primary_id, user.level)
    
    return PrimaryTargetResponse(id=primary_id, text=skill_text)



