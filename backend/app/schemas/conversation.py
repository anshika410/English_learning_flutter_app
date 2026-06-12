from pydantic import BaseModel
from datetime import datetime


class CreateConversationRequest(BaseModel):
    topic: str | None = None


class ConversationOut(BaseModel):
    id: str
    topic: str | None = None
    header_title: str | None = None
    duration_seconds: int | None = None
    session_type: str | None = None
    quality: str | None = None
    completed: bool = False
    created_at: datetime


from ..schemas.llm import SessionAnalysisResponse


class CompleteConversationRequest(BaseModel):
    duration_seconds: int | None = None
    session_type: str | None = None
    run_analysis: bool = False
    progression_model: str = "unit"
    level: str | None = None
    level_label: str | None = None


class CompleteConversationResponse(BaseModel):
    conversation: ConversationOut
    analysis: SessionAnalysisResponse | None = None


class MessageOut(BaseModel):
    id: str
    role: str
    content: str
    correction: str | None = None
    stt_duration_ms: int | None = None
    llm_duration_ms: int | None = None
    tts_duration_ms: int | None = None
    turn_number: int = 0
    created_at: datetime


class StoreMessageRequest(BaseModel):
    role: str
    content: str
    correction: str | None = None
    stt_duration_ms: int | None = None
    llm_duration_ms: int | None = None
    tts_duration_ms: int | None = None
    turn_number: int = 0
