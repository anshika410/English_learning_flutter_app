"""add zoe_recap to session_analysis

Revision ID: f790f7075a6a
Revises: a66d5198c72e
Create Date: 2026-07-04 12:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'f790f7075a6a'
down_revision: Union[str, None] = 'a66d5198c72e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add column zoe_recap to session_analyses table
    op.add_column('session_analyses', sa.Column('zoe_recap', sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column('session_analyses', 'zoe_recap')
