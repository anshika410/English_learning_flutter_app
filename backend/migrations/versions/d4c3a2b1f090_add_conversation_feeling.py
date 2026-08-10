"""add conversation feeling feedback

Revision ID: d4c3a2b1f090
Revises: a97b20fc0b08
Create Date: 2026-08-10
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d4c3a2b1f090"
down_revision: Union[str, None] = "a97b20fc0b08"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "conversations",
        sa.Column("student_feeling", sa.String(length=20), nullable=True),
    )
    op.add_column(
        "conversations",
        sa.Column("feeling_submitted_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("conversations", "feeling_submitted_at")
    op.drop_column("conversations", "student_feeling")
