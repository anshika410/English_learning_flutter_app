from pydantic import BaseModel, field_validator


class StarterRequest(BaseModel):
    topic: str | None = None


class StarterResponse(BaseModel):
    starter: str
    header_title: str


class MessageIn(BaseModel):
    role: str
    content: str


class ConversationTurnRequest(BaseModel):
    conversation_id: str
    messages: list[MessageIn]
    topic: str | None = None
    level: str = "A2"
    level_label: str = "Finding My Voice"
    current_turn: int = 1
    grammar_focus: str = "Catch All"
    vocab_focus: str = "Occasional"
    fluency_focus: str = "After Chat"


class ConversationTurnResponse(BaseModel):
    reply: str
    correction: str | None = None
    conversation_complete: bool = False


class PlacementTurnRequest(BaseModel):
    messages: list[MessageIn]
    name: str | None = None
    age: int | None = None


class PlacementTurnResponse(BaseModel):
    reply: str | None = None
    is_complete: bool = False
    name: str | None = None
    age: int | None = None
    age_group: str | None = None
    level_code: str | None = None
    level_name: str | None = None
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
    conversation_id: str
    messages: list[MessageIn]
    topic: str = "Free Talk"
    level: str = "A2"
    level_label: str = "Finding My Voice"
    progression_model: str = "unit"
