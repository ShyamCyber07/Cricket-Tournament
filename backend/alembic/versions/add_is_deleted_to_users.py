"""Add is_deleted field to users table

Revision ID: add_is_deleted_to_users
Revises: team_uniqueness_per_user
Create Date: 2026-06-20

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'add_is_deleted_to_users'
down_revision = 'team_uniqueness_per_user'
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table('users', schema=None) as batch_op:
        # Postgres rejects server_default='0' for a Boolean column (it expects
        # a boolean expression, not a text literal). Use sa.false() so the SQL
        # emitted is `DEFAULT false` on Postgres and `DEFAULT 0` on SQLite,
        # both of which the dialect accepts.
        batch_op.add_column(sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.false()))


def downgrade() -> None:
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('is_deleted')