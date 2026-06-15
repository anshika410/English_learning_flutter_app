from pydantic import BaseModel


class UserProfile(BaseModel):
    id: str
    device_id: str
    name: str | None = None
    age: str | None = None
    location: str | None = None
    level: str | None = None
    level_label: str | None = None
    grammar_focus: int = 2
    vocab_focus: int = 2
    fluency_focus: int = 1
    first_session_done: bool = False
    interests: list[str] | None = None
    persona_memory: dict | None = None
    skills_progress: dict | None = None
    due_next: dict | None = None


class UpdateProfileRequest(BaseModel):
    name: str | None = None
    age: str | None = None
    location: str | None = None


class UpdateSettingsRequest(BaseModel):
    grammar_focus: int | None = None
    vocab_focus: int | None = None
    fluency_focus: int | None = None


class UpdateMemoryRequest(BaseModel):
    persona_memory: dict


class MemoryProfileSub(BaseModel):
    name: str | None = "—"
    age: int | None = None
    city: str | None = "—"
    grade: str | None = None


class UserMemoryResponse(BaseModel):
    id: str
    device_id: str
    profile: MemoryProfileSub
    level: str | None = None
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



