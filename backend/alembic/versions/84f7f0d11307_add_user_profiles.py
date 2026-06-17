"""add_user_profiles

Revision ID: 84f7f0d11307
Revises: 5bcdf48f4d4f
Create Date: 2026-06-17 15:49:39.838360

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '84f7f0d11307'
down_revision: Union[str, None] = '5bcdf48f4d4f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add columns to users
    op.add_column('users', sa.Column('bio', sa.String(), nullable=True))
    op.add_column('users', sa.Column('account_type', sa.String(), nullable=True, server_default='Scorer'))
    op.add_column('users', sa.Column('joined_at', sa.DateTime(), nullable=True))

    # Create user_activities table
    op.create_table(
        'user_activities',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('activity_type', sa.String(), nullable=False),
        sa.Column('description', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # Create user_achievements table
    op.create_table(
        'user_achievements',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('achievement_type', sa.String(), nullable=False),
        sa.Column('unlocked_at', sa.DateTime(), nullable=True),
        sa.Column('is_unlocked', sa.Boolean(), nullable=True, server_default='false'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )


def downgrade() -> None:
    op.drop_table('user_achievements')
    op.drop_table('user_activities')
    op.drop_column('users', 'joined_at')
    op.drop_column('users', 'account_type')
    op.drop_column('users', 'bio')
