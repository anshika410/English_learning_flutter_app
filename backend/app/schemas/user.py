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


class UpdateProfileRequest(BaseModel):
    name: str | None = None
    age: str | None = None
    location: str | None = None


class UpdateSettingsRequest(BaseModel):
    grammar_focus: int | None = None
    vocab_focus: int | None = None
    fluency_focus: int | None = None
