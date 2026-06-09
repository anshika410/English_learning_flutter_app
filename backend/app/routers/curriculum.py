from fastapi import APIRouter
from ..schemas.curriculum import TopicOut

router = APIRouter(prefix="/curriculum", tags=["curriculum"])

# Seed topics from the design spec / frontend prototype
TOPICS = [
    {
        "id": "cricket",
        "name": "Cricket",
        "icon": "🏏",
        "color": "#E6F9E6",
        "highlight_color": "rgba(59,212,42,0.12)",
        "panel_bg": "linear-gradient(135deg,#E6F9E6,#D0F0D0)",
        "vocab_seeds": ["thrilling", "boundary", "consistent", "strategy", "opponent", "chase", "remarkable", "decisive"],
        "structure_targets": ["past tense narration", "because + reason", "opinion with justification", "sequencing with first/then/after"]
    },
    {
        "id": "bollywood",
        "name": "Bollywood",
        "icon": "🎬",
        "color": "#FFF0E0",
        "highlight_color": "rgba(255,107,44,0.1)",
        "panel_bg": "linear-gradient(135deg,#FFF0E0,#FFE4CC)",
        "vocab_seeds": ["inspiring", "plot", "character", "emotional", "scene", "dialogue", "entertaining", "powerful"],
        "structure_targets": ["past tense narration", "describing people", "expressing preferences with reasons"]
    },
    {
        "id": "school",
        "name": "School Life",
        "icon": "📚",
        "color": "#E0EDFF",
        "highlight_color": "rgba(45,127,249,0.08)",
        "panel_bg": "linear-gradient(135deg,#E0EDFF,#CCE0FF)",
        "vocab_seeds": ["challenging", "assignment", "concentrate", "improve", "schedule", "curious", "experiment", "participate"],
        "structure_targets": ["daily routines in present simple", "describing people", "explaining preferences"]
    },
    {
        "id": "food",
        "name": "Food",
        "icon": "🍕",
        "color": "#FFFDE0",
        "highlight_color": "rgba(255,210,63,0.12)",
        "panel_bg": "linear-gradient(135deg,#FFFDE0,#FFF5B0)",
        "vocab_seeds": ["delicious", "recipe", "ingredient", "flavour", "spicy", "prepare", "aroma", "combination"],
        "structure_targets": ["sequencing instructions", "describing sensory experience", "expressing preferences"]
    },
    {
        "id": "gaming",
        "name": "Gaming",
        "icon": "🎮",
        "color": "#F0E6FF",
        "highlight_color": "rgba(128,0,255,0.06)",
        "panel_bg": "linear-gradient(135deg,#F0E6FF,#E0D0FF)",
        "vocab_seeds": ["competitive", "strategy", "graphics", "achievement", "teammate", "challenge", "upgrade", "mission"],
        "structure_targets": ["past tense narration", "comparing things", "explaining rules/processes"]
    },
    {
        "id": "dream",
        "name": "My Dream",
        "icon": "🚀",
        "color": "#E8EAF6",
        "highlight_color": "rgba(45,127,249,0.06)",
        "panel_bg": "linear-gradient(135deg,#E8EAF6,#D0D4F0)",
        "vocab_seeds": ["opportunity", "ambitious", "profession", "contribute", "determined", "achievement", "inspire", "valuable"],
        "structure_targets": ["future tense", "conditional structures", "giving reasons for opinions"]
    }
]

@router.get("/topics", response_model=list[TopicOut])
async def list_topics():
    """Returns the list of curriculum topics for the user home screen."""
    return TOPICS
