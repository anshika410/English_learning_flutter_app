from pydantic import BaseModel, field_validator
from datetime import datetime
from typing import Any


class CreatePlacementRequest(BaseModel):
    level: str
    level_label: str | None = None
    confidence: str | None = None  # e.g. "high", "medium", "low"
    highlight: str | None = None
    transcript_json: Any | None = None  # accepts list or string
    interests: list[str] | None = None  # detected from placement conversation


class PlacementOut(BaseModel):
    id: str
    level: str
    level_label: str | None = None
    confidence: str | None = None
    highlight: str | None = None
    created_at: datetime
