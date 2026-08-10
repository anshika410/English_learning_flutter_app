import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Integer, Text, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from ..core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Conversation(Base):
    __tablename__ = "conversations"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    topic: Mapped[str | None] = mapped_column(String(100), nullable=True)
    header_title: Mapped[str | None] = mapped_column(String(100), nullable=True)
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    session_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    quality: Mapped[str | None] = mapped_column(String(20), nullable=True)
    student_feeling: Mapped[str | None] = mapped_column(String(20), nullable=True)
    feeling_submitted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    prompt_used: Mapped[str | None] = mapped_column(Text, nullable=True)  # The system prompt used in this session
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
