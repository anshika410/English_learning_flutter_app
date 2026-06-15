from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from ..core.database import get_db
from ..core.deps import get_current_user
from ..models.user import User
from ..schemas.user import UpdateProfileRequest, UpdateMemoryRequest, UserMemoryResponse

router = APIRouter(prefix="/users", tags=["users"])


def _to_memory_response(user: User) -> UserMemoryResponse:
    persona = user.persona_memory or {}
    progress = user.skills_progress or {}
    due = user.due_next or {}

    # Cast age to integer if it is a numeric string
    age_val = None
    if user.age and user.age.isdigit():
        age_val = int(user.age)

    profile_data = {
        "name": user.name if user.name else "—",
        "age": age_val,
        "city": user.location if user.location else "—",
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
        last_topics=persona.get("last_topics", []),
        persona_memory=user.persona_memory or {},
        skills_progress=user.skills_progress or {},
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


