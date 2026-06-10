"""add session grading

Revision ID: 003
Revises: 002
Create Date: 2026-06-10
"""
from alembic import op
import sqlalchemy as sa

revision = "003"
down_revision = "002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    
    # 1. Add columns to 'users' table
    user_columns = [col["name"] for col in inspector.get_columns("users")]
    if "skills_progress" not in user_columns:
        op.add_column("users", sa.Column("skills_progress", sa.JSON(), nullable=True))
    if "due_next" not in user_columns:
        op.add_column("users", sa.Column("due_next", sa.JSON(), nullable=True))

    # 2. Add columns to 'session_analyses' table
    sa_columns = [col["name"] for col in inspector.get_columns("session_analyses")]
    if "aimed_at" not in sa_columns:
        op.add_column("session_analyses", sa.Column("aimed_at", sa.JSON(), nullable=True))
    if "hit_targets" not in sa_columns:
        op.add_column("session_analyses", sa.Column("hit_targets", sa.JSON(), nullable=True))
    if "skills_evidenced" not in sa_columns:
        op.add_column("session_analyses", sa.Column("skills_evidenced", sa.JSON(), nullable=True))
    if "state_changes" not in sa_columns:
        op.add_column("session_analyses", sa.Column("state_changes", sa.JSON(), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    
    # 1. Drop columns from 'users' table
    user_columns = [col["name"] for col in inspector.get_columns("users")]
    if "due_next" in user_columns:
        op.drop_column("users", "due_next")
    if "skills_progress" in user_columns:
        op.drop_column("users", "skills_progress")

    # 2. Drop columns from 'session_analyses' table
    sa_columns = [col["name"] for col in inspector.get_columns("session_analyses")]
    if "state_changes" in sa_columns:
        op.drop_column("session_analyses", "state_changes")
    if "skills_evidenced" in sa_columns:
        op.drop_column("session_analyses", "skills_evidenced")
    if "hit_targets" in sa_columns:
        op.drop_column("session_analyses", "hit_targets")
    if "aimed_at" in sa_columns:
        op.drop_column("session_analyses", "aimed_at")
