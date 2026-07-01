from pydantic import BaseModel, Field
from datetime import datetime


class CreateConversationRequest(BaseModel):
    unit: str | None = None

    model_config = {
        "json_schema_extra": {
            "example": {
                "unit": "Describing the world"
            }
        }
    }


class ConversationOut(BaseModel):
    session_id: str
    unit: str | None = None
    starter: str | None = None
    level: str | None = None
    aimed_at: list[str] | None = None
    completed: bool = False
    created_at: datetime




class MessageOut(BaseModel):
    id: str
    role: str
    content: str
    turn_number: int = 0
    created_at: datetime


class StoreMessageRequest(BaseModel):
    role: str
    content: str
    turn_number: int = 0

    model_config = {
        "json_schema_extra": {
            "example": {
                "role": "user",
                "content": "Hello Zoe! I want to talk about dogs today.",
                "turn_number": 1
            }
        }
    }


class SessionLogTranscriptMessage(BaseModel):
    role: str
    content: str


class SessionLogGradedSkill(BaseModel):
    id: str
    name: str
    confidence: float
    prompted: bool
    evidence: str
    reason: str


class SessionLogStateChange(BaseModel):
    id: str
    from_state: str = Field(alias="from")
    to_state: str = Field(alias="to")
    name: str

    model_config = {
        "populate_by_name": True
    }


class SessionLogResponse(BaseModel):
    session_id: str
    user_id: str
    level: str | None
    progression_model: str
    prompt_version: str
    timestamp: datetime
    turns_total: int
    unit: str | None
    aimed_at: list[str]
    hit_targets: list[str]
    skills_evidenced: list[SessionLogGradedSkill]
    state_changes: list[SessionLogStateChange]
    transcript: list[SessionLogTranscriptMessage]


class ConversationTurnRequest(BaseModel):
    content: str

    model_config = {
        "json_schema_extra": {
            "example": {
                "content": "Yes, I have a big golden retriever."
            }
        }
    }


class ConversationTurnResponse(BaseModel):
    transcript: list[SessionLogTranscriptMessage]
    conversation_complete: bool = False

