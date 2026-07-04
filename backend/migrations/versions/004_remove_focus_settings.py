"""remove focus settings

Revision ID: 004
Revises: 003
Create Date: 2026-06-15
"""
from alembic import op
import sqlalchemy as sa

revision = "004"
down_revision = "003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [col["name"] for col in inspector.get_columns("users")]

    if "grammar_focus" in columns:
        op.drop_column("users", "grammar_focus")
    if "vocab_focus" in columns:
        op.drop_column("users", "vocab_focus")
    if "fluency_focus" in columns:
        op.drop_column("users", "fluency_focus")


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [col["name"] for col in inspector.get_columns("users")]

    if "grammar_focus" not in columns:
        op.add_column("users", sa.Column("grammar_focus", sa.Integer(), nullable=False, server_default="2"))
    if "vocab_focus" not in columns:
        op.add_column("users", sa.Column("vocab_focus", sa.Integer(), nullable=False, server_default="2"))
    if "fluency_focus" not in columns:
        op.add_column("users", sa.Column("fluency_focus", sa.Integer(), nullable=False, server_default="1"))
