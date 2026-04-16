from pydantic import BaseModel
from datetime import datetime


class CreatePlacementRequest(BaseModel):
    level: str
    level_label: str | None = None
    confidence: float | None = None
    highlight: str | None = None
    transcript_json: str | None = None


class PlacementOut(BaseModel):
    id: str
    level: str
    level_label: str | None = None
    confidence: float | None = None
    highlight: str | None = None
    created_at: datetime
