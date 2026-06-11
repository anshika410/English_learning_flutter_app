from fastapi import APIRouter, Depends
from ..schemas.curriculum import TopicOut
from ..core.deps import get_current_user
from ..models.user import User
from ..core.curriculum_data import LEVEL_TOPICS

router = APIRouter(prefix="/curriculum", tags=["curriculum"])

@router.get("/topics", response_model=list[TopicOut])
async def list_topics(user: User = Depends(get_current_user)):
    """Returns the list of curriculum topics for the user home screen based on their CEFR level."""
    level = user.level or "A1"
    topics = LEVEL_TOPICS.get(level.upper(), LEVEL_TOPICS.get("A1", []))
    return topics

