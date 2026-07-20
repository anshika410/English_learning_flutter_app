import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Boolean, Integer, DateTime, JSON, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..core.database import Base
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .placement import Placement


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class RefreshSession(Base):
    __tablename__ = "refresh_sessions"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(String(36), index=True)
    refresh_token: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    # Anonymous identity — device UUID sent from the app on first launch
    device_id: Mapped[str | None] = mapped_column(String(64), unique=True, index=True, nullable=True)

    # Auth Email (for magic link / google)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, index=True, nullable=True)

    # Profile — filled in during/after placement
    name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    age: Mapped[str | None] = mapped_column(String(10), nullable=True)
    location: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # CEFR level from placement
    level: Mapped[str | None] = mapped_column(String(5), nullable=True)
    level_label: Mapped[str | None] = mapped_column(String(150), nullable=True)

    @property
    def first_name(self) -> str | None:
        if not self.name:
            return None
        return self.name.strip().split(" ")[0]

    @property
    def unit_label(self) -> str | None:
        return self.level_label

    @unit_label.setter
    def unit_label(self, value: str | None) -> None:
        self.level_label = value

    # Interests detected during placement (comma-separated, e.g. "cricket,music,food")
    interests: Mapped[str | None] = mapped_column(Text, nullable=True)

    first_session_done: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Permanent student memory block (hobbies, pets, weakness lists, etc.)
    persona_memory: Mapped[dict | None] = mapped_column(JSON, nullable=True, default=dict)

    # CEFR flat skills checklist state (emerging, owned, sightings, strength, last_seen)
    skills_progress: Mapped[dict | None] = mapped_column(JSON, nullable=True, default=dict)

    # Current target skills for Zoe
    due_next: Mapped[dict | None] = mapped_column(JSON, nullable=True, default=dict)

    placements: Mapped[list["Placement"]] = relationship(
        "Placement",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow
    )
