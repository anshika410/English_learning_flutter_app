from pydantic import BaseModel


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


class PlacementTurnResponse(BaseModel):
    reply: str | None = None
    is_complete: bool = False
    name: str | None = None
    age: str | None = None
    location: str | None = None
    assessed_level: str | None = None
    confidence: str | None = None


class SessionAnalysisRequest(BaseModel):
    conversation_id: str
    messages: list[MessageIn]
    topic: str = "Free Talk"
    level: str = "A2"
    level_label: str = "Finding My Voice"
