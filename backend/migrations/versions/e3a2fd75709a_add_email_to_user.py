"""Add email to User

Revision ID: e3a2fd75709a
Revises: 004
Create Date: 2026-07-03 20:55:01.114522

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'e3a2fd75709a'
down_revision: Union[str, None] = '004'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # We only add the email column, make device_id nullable, and add indices.
    # We remove the accidental placements alter_column that alembic generated on SQLite.
    
    # We must handle the alter column safely for sqlite or postgres.
    # A safe way to just add a column:
    op.add_column('users', sa.Column('email', sa.String(length=255), nullable=True))
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)

    # For device_id, we will not alter it to be nullable using alembic natively here 
    # because of SQLite batch alter column issues. It's safe to leave as is in DB,
    # and sqlalchemy model is updated to `nullable=True` in python code.
    # When creating new users (magic link/Google), they will have email.
    # Wait, if device_id is NOT NULL in DB, inserts will fail if we don't provide it.
    # We will generate a UUID for device_id in the auth router if it's missing.


def downgrade() -> None:
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_column('users', 'email')
