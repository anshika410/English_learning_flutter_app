import uuid
import json
from datetime import datetime, timezone
from sqlalchemy import String, Text, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from ..core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Placement(Base):
    __tablename__ = "placements"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    level: Mapped[str] = mapped_column(String(5))
    level_label: Mapped[str | None] = mapped_column(String(50), nullable=True)

    @property
    def unit_label(self) -> str | None:
        return self.level_label

    @unit_label.setter
    def unit_label(self, value: str | None) -> None:
        self.level_label = value

    confidence: Mapped[str | None] = mapped_column(String(20), nullable=True)
    highlight: Mapped[str | None] = mapped_column(Text, nullable=True)
    transcript_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
