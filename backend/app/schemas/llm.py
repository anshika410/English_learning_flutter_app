from pydantic import BaseModel, field_validator, Field


class StarterRequest(BaseModel):
    unit: str | None = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "unit": "School and Friends"
            }
        }
    }


class StarterResponse(BaseModel):
    starter: str
    header_title: str


class MessageIn(BaseModel):
    role: str
    content: str


class ConversationTurnRequest(BaseModel):
    session_id: str
    messages: list[MessageIn]
    unit: str | None = None
    level: str = "A2"
    unit_label: str = "Finding My Voice"
    current_turn: int = 1

    model_config = {
        "json_schema_extra": {
            "example": {
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "messages": [
                    {"role": "system", "content": "You are Zoe, a friendly English tutor."},
                    {"role": "assistant", "content": "Hi there! Let's talk about sports. Do you play cricket?"},
                    {"role": "user", "content": "Yes, I play cricket with my friends every Sunday."}
                ],
                "topic": "Sports",
                "level": "A2",
                "unit_label": "Finding My Voice",
                "current_turn": 3
            }
        }
    }


class ConversationTurnResponse(BaseModel):
    reply: str
    correction: str | None = None
    conversation_complete: bool = False


class PlacementTurnRequest(BaseModel):
    messages: list[MessageIn]
    name: str | None = None
    age: int | None = None
    cancel: bool = False

    model_config = {
        "json_schema_extra": {
            "example": {
                "messages": [
                    {"role": "assistant", "content": "Hi! What is your name?"},
                    {"role": "user", "content": "My name is Raj."}
                ],
                "name": "Raj",
                "age": 10
            }
        }
    }


class PlacementTurnResponse(BaseModel):
    reply: str | None = None
    is_complete: bool = False
    name: str | None = None
    age: int | None = None
    age_group: str | None = None
    level: str | None = None
    unit_name: str | None = None
    level_description: str | None = None
    confidence: str | None = None
    possible_higher: bool | None = None
    evidence_summary: str | None = None
    probe_targets_covered: list[str] | None = None
    turns_taken: int | None = None
    code_switch_observed: bool | None = None
    notes_for_first_session: str | None = None
    interests: list[str] | None = None

    @field_validator('age', 'turns_taken', mode='before')
    @classmethod
    def coerce_int(cls, v):
        if v is None:
            return None
        try:
            return int(v)
        except (ValueError, TypeError):
            return None


class SessionAnalysisRequest(BaseModel):
    session_id: str
    messages: list[MessageIn]
    unit: str | None = None
    level: str = "A2"
    unit_label: str = "Finding My Voice"
    progression_model: str = "unit"
    session_type: str | None = None
    turns_total: int | None = Field(default=None, description="Total turns taken in the session")

    model_config = {
        "json_schema_extra": {
            "example": {
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "messages": [
                    {"role": "assistant", "content": "Hi! Let's talk about food. What did you eat for breakfast?"},
                    {"role": "user", "content": "I ate dosas and drank some milk."}
                ],
                "unit": "Food",
                "level": "A2",
                "unit_label": "Finding My Voice",
                "progression_model": "unit",
                "turns_total": 2
            }
        }
    }


class BestMoment(BaseModel):
    quote: str | None = None
    note: str | None = None


class CourageHighlight(BaseModel):
    type: str | None = None
    content: str | None = None


class TryNextTime(BaseModel):
    skill: str | None = None
    example: str | None = None


class GradedSkillScore(BaseModel):
    id: str
    confidence: float
    prompted: bool
    support_level: str | None = None
    evidence: str | None = None


class StateChangeDetail(BaseModel):
    id: str
    from_: str = Field(alias="from")
    to: str
    name: str

    model_config = {
        "populate_by_name": True
    }


class TranscriptNote(BaseModel):
    speaker: str
    text: str
    note: str | None = None


class SessionAnalysisResponse(BaseModel):
    overall: str | None = None
    best_moment: dict | None = None
    courage_or_motivation: dict | None = None
    try_next_time: dict | None = None
    zoe_recap: str | None = None
    extracted_memory_facts: list[str] = []
    transcript_notes: list[TranscriptNote] = []
    aimed_at: list[str] = []
    hit_targets: list[str] = []
    skills_evidenced: list[GradedSkillScore] = []
    state_changes: list[StateChangeDetail] = []
