import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Boolean, Integer, DateTime, JSON
from sqlalchemy.orm import Mapped, mapped_column
from ..core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    # Anonymous identity — device UUID sent from the app on first launch
    device_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)

    # Profile — filled in during/after placement
    name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    age: Mapped[str | None] = mapped_column(String(10), nullable=True)
    location: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # CEFR level from placement
    level: Mapped[str | None] = mapped_column(String(5), nullable=True)
    level_label: Mapped[str | None] = mapped_column(String(50), nullable=True)

    # Interests detected during placement (comma-separated, e.g. "cricket,music,food")
    interests: Mapped[str | None] = mapped_column(String(200), nullable=True)

    # Focus settings (stored as enum indices matching Flutter FocusSettings)
    grammar_focus: Mapped[int] = mapped_column(Integer, default=2)
    vocab_focus: Mapped[int] = mapped_column(Integer, default=2)
    fluency_focus: Mapped[int] = mapped_column(Integer, default=1)

    first_session_done: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Permanent student memory block (hobbies, pets, weakness lists, etc.)
    persona_memory: Mapped[dict | None] = mapped_column(JSON, nullable=True, default=dict)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )
