import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column
from ..core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class SessionAnalysis(Base):
    __tablename__ = "session_analyses"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    conversation_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("conversations.id"), unique=True, index=True
    )
    overall: Mapped[str] = mapped_column(String(20))
    best_moment_quote: Mapped[str | None] = mapped_column(Text, nullable=True)
    best_moment_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    courage_type: Mapped[str | None] = mapped_column(String(30), nullable=True)
    courage_content: Mapped[str | None] = mapped_column(Text, nullable=True)
    try_next_skill: Mapped[str | None] = mapped_column(Text, nullable=True)
    try_next_example: Mapped[str | None] = mapped_column(Text, nullable=True)
    zoe_recap: Mapped[str | None] = mapped_column(Text, nullable=True)
    transcript_notes_json: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Structured CEFR grading and progress columns
    aimed_at: Mapped[dict | list | None] = mapped_column(JSON, nullable=True)
    hit_targets: Mapped[dict | list | None] = mapped_column(JSON, nullable=True)
    skills_evidenced: Mapped[dict | list | None] = mapped_column(JSON, nullable=True)
    state_changes: Mapped[dict | list | None] = mapped_column(JSON, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
