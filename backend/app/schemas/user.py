from pydantic import BaseModel


class UserProfile(BaseModel):
    id: str
    device_id: str
    name: str | None = None
    age: str | None = None
    location: str | None = None
    level: str | None = None
    unit_label: str | None = None
    first_session_done: bool = False
    interests: list[str] | None = None
    persona_memory: dict | None = None
    skills_progress: dict | None = None
    due_next: dict | None = None


class UpdateProfileRequest(BaseModel):
    name: str | None = None
    age: str | None = None
    location: str | None = None
    level: str | None = None
    unit: str | None = None
    unit_label: str | None = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "name": "Aarav",
                "age": "12",
                "location": "Delhi",
                "level": "A2",
                "unit_label": "First Words"
            }
        }
    }


class UpdateMemoryRequest(BaseModel):
    persona_memory: dict

    model_config = {
        "json_schema_extra": {
            "example": {
                "persona_memory": {
                    "likes": "playing cricket",
                    "has_pet": "dog named Max",
                    "favorite_food": "mangoes"
                }
            }
        }
    }


class MemoryProfileSub(BaseModel):
    name: str | None = None
    age: int | None = None
    city: str | None = None
    grade: str | None = None


class PlacementSubResponse(BaseModel):
    level: str
    unit_label: str | None = None
    confidence: str | None = None
    highlight: str | None = None
    created_at: str


class NextTopicItem(BaseModel):
    name: str
    label: str
    starter: str | None = None


class NextTopics(BaseModel):
    recommended: NextTopicItem
    alternatives: list[NextTopicItem] = []


class UserMemoryResponse(BaseModel):
    id: str
    device_id: str
    profile: MemoryProfileSub
    level: str | None = None
    first_session_done: bool = False
    interests: list[str] = []
    last_time_recap: str | None = None
    placement: PlacementSubResponse | None = None
    owned: list[str] = []
    emerging: list[str] = []
    due_next: dict = {}
    next_topics: NextTopics | None = None
    effort: dict = {"times_spoken_total": 0}
    sightings: dict = {}
    strength: dict = {}
    updated_after_chat: int = 0
    units: list[str] = []
    last_topics: list[str] = []
    persona_memory: dict = {}


class GardenEvidence(BaseModel):
    evidence: str
    confidence: float
    prompted: bool
    topic: str | None = None
    created_at: str | None = None


class GardenSkill(BaseModel):
    id: str
    strand: str
    text: str
    status: str  # "owned", "emerging", "locked"
    sightings: int
    last_tested_at: str | None = None
    evidence: list[GardenEvidence] = []


class GardenUnit(BaseModel):
    unit: int
    name: str
    focus: str
    skills: list[GardenSkill]


class GardenResponse(BaseModel):
    level: str
    recommended_topic: str
    units: list[GardenUnit]


class TopicResponse(BaseModel):
    id: str
    name: str
    theme: str
    description: str
    icon: str
    color: str
    highlight_color: str
    panel_bg: str
    vocab_seeds: list[str]
    structure_targets: list[str]
    starters: list[str]





