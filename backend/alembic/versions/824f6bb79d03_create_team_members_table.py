"""create_team_members_table

Revision ID: 824f6bb79d03
Revises: add_is_deleted_to_users
Create Date: 2026-06-21 18:23:10.669674

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '824f6bb79d03'
down_revision: Union[str, None] = 'add_is_deleted_to_users'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    from datetime import datetime, timezone
    import uuid

    op.create_table(
        'team_members',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('team_id', sa.UUID(), sa.ForeignKey('teams.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', sa.UUID(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('role', sa.String(), nullable=False),
        sa.Column('joined_at', sa.DateTime(), nullable=False),
        sa.Column('status', sa.String(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )

    # Populate team_members for all existing teams
    connection = op.get_bind()
    teams = connection.execute(sa.text("SELECT id, created_by, created_at FROM teams")).fetchall()
    for team in teams:
        member_id = uuid.uuid4()
        connection.execute(sa.text(
            "INSERT INTO team_members (id, team_id, user_id, role, joined_at, status) "
            "VALUES (:id, :team_id, :user_id, 'captain', :joined_at, 'active')"
        ), {
            "id": member_id,
            "team_id": team.id,
            "user_id": team.created_by,
            "joined_at": team.created_at or datetime.now(timezone.utc)
        })


def downgrade() -> None:
    op.drop_table('team_members')
