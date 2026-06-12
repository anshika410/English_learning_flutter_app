from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..schemas.user import UserProfile, UpdateProfileRequest, UpdateSettingsRequest, UpdateMemoryRequest

router = APIRouter(prefix="/users", tags=["users"])


def _to_profile(user: User) -> UserProfile:
    return UserProfile(
        id=user.id,
        device_id=user.device_id,
        name=user.name,
        age=user.age,
        location=user.location,
        level=user.level,
        level_label=user.level_label,
        grammar_focus=user.grammar_focus,
        vocab_focus=user.vocab_focus,
        fluency_focus=user.fluency_focus,
        first_session_done=user.first_session_done,
        interests=user.interests.split(",") if user.interests else None,
        persona_memory=user.persona_memory or {},
        skills_progress=user.skills_progress or {},
        due_next=user.due_next or {},
    )


@router.get("/me", response_model=UserProfile)
async def get_profile(user: User = Depends(get_current_user)):
    return _to_profile(user)


@router.put("/me", response_model=UserProfile)
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
    db.add(user)
    await db.flush()
    return _to_profile(user)


@router.put("/me/settings", response_model=UserProfile)
async def update_settings(
    body: UpdateSettingsRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.grammar_focus is not None:
        user.grammar_focus = body.grammar_focus
    if body.vocab_focus is not None:
        user.vocab_focus = body.vocab_focus
    if body.fluency_focus is not None:
        user.fluency_focus = body.fluency_focus
    db.add(user)
    await db.flush()
    return _to_profile(user)


@router.get("/me/memory")
async def get_user_memory(
    user: User = Depends(get_current_user)
):
    """
    Returns the student's full learning memory as a unified object.
    Combines profile, persona facts, skills progress, and next targets.
    """
    persona = user.persona_memory or {}
    progress = user.skills_progress or {}
    due = user.due_next or {}

    return {
        "profile": {
            "name": user.name,
            "age": user.age,
            "city": user.location,
            "grade": None,
        },
        "level": user.level,
        "owned": progress.get("owned", []),
        "emerging": progress.get("emerging", []),
        "due_next": due,
        "last_topics": persona.get("last_topics", []),
        "interests": user.interests.split(",") if user.interests else [],
        "effort": progress.get("effort", {"times_spoken_total": 0}),
        "sightings": progress.get("sightings", {}),
        "strength": progress.get("strength", {}),
        "updated_after_chat": progress.get("updated_after_chat", 0),
    }


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

