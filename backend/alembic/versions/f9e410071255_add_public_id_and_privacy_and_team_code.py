"""add_public_id_and_privacy_and_team_code

Revision ID: f9e410071255
Revises: 0d71c3d166af
Create Date: 2026-06-29 22:14:35.566015

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
import uuid

# revision identifiers, used by Alembic.
revision: str = 'f9e410071255'
down_revision: Union[str, None] = '0d71c3d166af'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def generate_unique_code(prefix, existing_codes):
    while True:
        code = f"{prefix}-{uuid.uuid4().hex[:6].upper()}"
        if code not in existing_codes:
            existing_codes.add(code)
            return code


def upgrade() -> None:
    # 1. Add columns to users
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('public_id', sa.String(), nullable=True))
        batch_op.add_column(sa.Column('privacy_settings', sa.String(), nullable=False, server_default='public'))

    # 2. Add column to teams
    with op.batch_alter_table('teams', schema=None) as batch_op:
        batch_op.add_column(sa.Column('team_code', sa.String(), nullable=True))

    # 3. Populate existing users and teams with unique codes
    connection = op.get_bind()
    
    # Update users
    users = connection.execute(sa.text("SELECT id FROM users")).fetchall()
    existing_user_codes = set()
    for user in users:
        code = generate_unique_code("CU", existing_user_codes)
        connection.execute(
            sa.text("UPDATE users SET public_id = :code WHERE id = :id"),
            {"code": code, "id": user.id}
        )

    # Update teams
    teams = connection.execute(sa.text("SELECT id FROM teams")).fetchall()
    existing_team_codes = set()
    for team in teams:
        code = generate_unique_code("TC", existing_team_codes)
        connection.execute(
            sa.text("UPDATE teams SET team_code = :code WHERE id = :id"),
            {"code": code, "id": team.id}
        )

    # 4. Create unique indexes
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.create_index('ix_users_public_id', ['public_id'], unique=True)

    with op.batch_alter_table('teams', schema=None) as batch_op:
        batch_op.create_index('ix_teams_team_code', ['team_code'], unique=True)


def downgrade() -> None:
    with op.batch_alter_table('teams', schema=None) as batch_op:
        batch_op.drop_index('ix_teams_team_code')
        batch_op.drop_column('team_code')

    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_index('ix_users_public_id')
        batch_op.drop_column('privacy_settings')
        batch_op.drop_column('public_id')
