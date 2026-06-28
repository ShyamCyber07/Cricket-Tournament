"""add_team_stabilization_fields_and_activity

Revision ID: 06ed4a631074
Revises: c5dcf1cafea4
Create Date: 2026-06-28 14:26:36.288328

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '06ed4a631074'
down_revision: Union[str, None] = 'c5dcf1cafea4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add fields to teams table
    with op.batch_alter_table('teams', schema=None) as batch_op:
        batch_op.add_column(sa.Column('is_squad_locked', sa.Boolean(), server_default='false', nullable=False))
        batch_op.add_column(sa.Column('home_ground', sa.String(), nullable=True))
        batch_op.add_column(sa.Column('city', sa.String(), nullable=True))
        batch_op.add_column(sa.Column('team_motto', sa.String(), nullable=True))
        batch_op.add_column(sa.Column('founded_year', sa.Integer(), nullable=True))

    # 2. Add invited_by_id to team_members table
    with op.batch_alter_table('team_members', schema=None) as batch_op:
        batch_op.add_column(sa.Column('invited_by_id', sa.UUID(), sa.ForeignKey('users.id', name='fk_team_members_invited_by_id_users', ondelete='SET NULL'), nullable=True))

    # 3. Create team_activities table
    op.create_table('team_activities',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('team_id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=True),
        sa.Column('action_type', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['team_id'], ['teams.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )


def downgrade() -> None:
    op.drop_table('team_activities')
    with op.batch_alter_table('team_members', schema=None) as batch_op:
        batch_op.drop_column('invited_by_id')
    with op.batch_alter_table('teams', schema=None) as batch_op:
        batch_op.drop_column('founded_year')
        batch_op.drop_column('team_motto')
        batch_op.drop_column('city')
        batch_op.drop_column('home_ground')
        batch_op.drop_column('is_squad_locked')
