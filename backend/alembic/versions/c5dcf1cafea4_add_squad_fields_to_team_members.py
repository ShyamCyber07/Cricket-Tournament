"""add squad fields to team members

Revision ID: c5dcf1cafea4
Revises: ea78bf102aaf
Create Date: 2026-06-28 13:02:32.166691

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c5dcf1cafea4'
down_revision: Union[str, None] = 'ea78bf102aaf'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('team_members', sa.Column('is_playing_xi', sa.Boolean(), server_default='true', nullable=False))
    op.add_column('team_members', sa.Column('is_wicketkeeper', sa.Boolean(), server_default='false', nullable=False))
    op.add_column('team_members', sa.Column('jersey_number', sa.Integer(), nullable=True))
    op.add_column('team_members', sa.Column('batting_order', sa.Integer(), nullable=True))
    op.add_column('team_members', sa.Column('bowling_order', sa.Integer(), nullable=True))
    op.add_column('team_members', sa.Column('is_available', sa.Boolean(), server_default='true', nullable=False))


def downgrade() -> None:
    op.drop_column('team_members', 'is_playing_xi')
    op.drop_column('team_members', 'is_wicketkeeper')
    op.drop_column('team_members', 'jersey_number')
    op.drop_column('team_members', 'batting_order')
    op.drop_column('team_members', 'bowling_order')
    op.drop_column('team_members', 'is_available')
