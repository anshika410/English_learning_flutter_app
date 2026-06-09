"""add persona memory

Revision ID: 002
Revises: 001
Create Date: 2026-06-09
"""
from alembic import op
import sqlalchemy as sa

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [col["name"] for col in inspector.get_columns("users")]

    if "persona_memory" not in columns:
        op.add_column("users", sa.Column("persona_memory", sa.JSON(), nullable=True))
    if "interests" not in columns:
        op.add_column("users", sa.Column("interests", sa.String(200), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [col["name"] for col in inspector.get_columns("users")]

    if "interests" in columns:
        op.drop_column("users", "interests")
    if "persona_memory" in columns:
        op.drop_column("users", "persona_memory")
