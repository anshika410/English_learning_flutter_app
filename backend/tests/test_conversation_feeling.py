import asyncio
from types import SimpleNamespace

import pytest
from pydantic import ValidationError

from backend.app.routers import conversations, users
from backend.app.schemas.conversation import ConversationFeelingRequest


class _FakeDb:
    def __init__(self, scalar=0):
        self.scalar = scalar
        self.added = []
        self.flushed = 0
        self.statement = None

    async def execute(self, statement):
        self.statement = statement
        return SimpleNamespace(scalar_one=lambda: self.scalar)

    def add(self, value):
        self.added.append(value)

    async def flush(self):
        self.flushed += 1


def test_feeling_request_accepts_only_supported_values():
    assert ConversationFeelingRequest(feeling="great").feeling == "great"
    assert ConversationFeelingRequest(feeling="okay").feeling == "okay"
    assert ConversationFeelingRequest(feeling="not_great").feeling == "not_great"
    with pytest.raises(ValidationError):
        ConversationFeelingRequest(feeling="bad")


def test_save_feeling_is_repeatable_for_an_owned_session(monkeypatch):
    conversation = SimpleNamespace(
        id="session-3",
        student_feeling=None,
        feeling_submitted_at=None,
    )

    async def owned(session_id, user_id, db):
        assert session_id == "session-3"
        assert user_id == "user-1"
        return conversation

    monkeypatch.setattr(conversations, "_get_owned", owned)
    db = _FakeDb()
    user = SimpleNamespace(id="user-1")
    request = ConversationFeelingRequest(feeling="not_great")

    first = asyncio.run(
        conversations.save_conversation_feeling("session-3", request, user, db)
    )
    second = asyncio.run(
        conversations.save_conversation_feeling("session-3", request, user, db)
    )

    assert first.feeling == second.feeling == "not_great"
    assert conversation.student_feeling == "not_great"
    assert conversation.feeling_submitted_at is not None
    assert db.flushed == 1


def test_completed_count_uses_the_database_result():
    db = _FakeDb(scalar=9)
    count = asyncio.run(users._completed_conversation_count("user-1", db))
    assert count == 9
    assert db.statement is not None
