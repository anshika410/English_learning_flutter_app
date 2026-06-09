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
    op.add_column("users", sa.Column("persona_memory", sa.JSON(), nullable=True))
    op.add_column("users", sa.Column("interests", sa.String(200), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "interests")
    op.drop_column("users", "persona_memory")
