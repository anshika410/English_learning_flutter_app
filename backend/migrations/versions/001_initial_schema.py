"""initial schema

Revision ID: 001
Revises:
Create Date: 2026-04-15
"""
from alembic import op
import sqlalchemy as sa

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("device_id", sa.String(64), nullable=False, unique=True),
        sa.Column("name", sa.String(100), nullable=True),
        sa.Column("age", sa.String(10), nullable=True),
        sa.Column("location", sa.String(100), nullable=True),
        sa.Column("level", sa.String(5), nullable=True),
        sa.Column("level_label", sa.String(50), nullable=True),
        sa.Column("grammar_focus", sa.Integer, nullable=False, server_default="2"),
        sa.Column("vocab_focus", sa.Integer, nullable=False, server_default="2"),
        sa.Column("fluency_focus", sa.Integer, nullable=False, server_default="1"),
        sa.Column("first_session_done", sa.Boolean, nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_users_device_id", "users", ["device_id"])

    op.create_table(
        "placements",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("level", sa.String(5), nullable=False),
        sa.Column("level_label", sa.String(50), nullable=True),
        sa.Column("confidence", sa.Float, nullable=True),
        sa.Column("highlight", sa.Text, nullable=True),
        sa.Column("transcript_json", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_placements_user_id", "placements", ["user_id"])

    op.create_table(
        "conversations",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("topic", sa.String(100), nullable=True),
        sa.Column("header_title", sa.String(100), nullable=True),
        sa.Column("duration_seconds", sa.Integer, nullable=True),
        sa.Column("session_type", sa.String(20), nullable=True),
        sa.Column("quality", sa.String(20), nullable=True),
        sa.Column("completed", sa.Boolean, nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_conversations_user_id", "conversations", ["user_id"])

    op.create_table(
        "messages",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("conversation_id", sa.String(36), sa.ForeignKey("conversations.id"), nullable=False),
        sa.Column("role", sa.String(20), nullable=False),
        sa.Column("content", sa.Text, nullable=False),
        sa.Column("correction", sa.Text, nullable=True),
        sa.Column("stt_duration_ms", sa.Integer, nullable=True),
        sa.Column("llm_duration_ms", sa.Integer, nullable=True),
        sa.Column("tts_duration_ms", sa.Integer, nullable=True),
        sa.Column("turn_number", sa.Integer, nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_messages_conversation_id", "messages", ["conversation_id"])

    op.create_table(
        "session_analyses",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("conversation_id", sa.String(36), sa.ForeignKey("conversations.id"), nullable=False, unique=True),
        sa.Column("overall", sa.String(20), nullable=False),
        sa.Column("best_moment_quote", sa.Text, nullable=True),
        sa.Column("best_moment_note", sa.Text, nullable=True),
        sa.Column("courage_type", sa.String(30), nullable=True),
        sa.Column("courage_content", sa.Text, nullable=True),
        sa.Column("try_next_skill", sa.Text, nullable=True),
        sa.Column("try_next_example", sa.Text, nullable=True),
        sa.Column("transcript_notes_json", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_session_analyses_conversation_id", "session_analyses", ["conversation_id"])


def downgrade() -> None:
    op.drop_table("session_analyses")
    op.drop_table("messages")
    op.drop_table("conversations")
    op.drop_table("placements")
    op.drop_table("users")
