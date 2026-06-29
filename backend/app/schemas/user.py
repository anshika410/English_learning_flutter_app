from pydantic import BaseModel


class UserProfile(BaseModel):
    id: str
    device_id: str
    name: str | None = None
    age: str | None = None
    location: str | None = None
    level: str | None = None
    level_label: str | None = None
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
    level_label: str | None = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "name": "Aarav",
                "age": "12",
                "location": "Delhi",
                "level": "A2",
                "level_label": "First Words"
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


class UserMemoryResponse(BaseModel):
    id: str
    device_id: str
    profile: MemoryProfileSub
    level: str | None = None
    first_session_done: bool = False
    interests: list[str] = []
    owned: list[str] = []
    emerging: list[str] = []
    due_next: dict = {}
    effort: dict = {"times_spoken_total": 0}
    sightings: dict = {}
    strength: dict = {}
    updated_after_chat: int = 0
    last_topics: list[str] = []
    persona_memory: dict = {}


class GardenEvidence(BaseModel):
    evidence: str
    confidence: float
    prompted: bool


class GardenSkill(BaseModel):
    id: str
    strand: str
    text: str
    status: str  # "owned", "emerging", "locked"
    sightings: int
    evidence: list[GardenEvidence] = []


class GardenStep(BaseModel):
    step: int
    name: str
    focus: str
    skills: list[GardenSkill]


class GardenResponse(BaseModel):
    level: str
    level_label: str
    recommended_topic: str
    steps: list[GardenStep]





