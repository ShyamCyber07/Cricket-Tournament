"""Change team name uniqueness from global to per-user.

Revision ID: team_uniqueness_per_user
Revises:
Create Date: 2026-06-20

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'team_uniqueness_per_user'
down_revision = '150e7fa72c85_add_role_and_reports'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Step 1: Drop the existing global unique index on name
    op.drop_index('ix_teams_name', table_name='teams')

    # Step 2: Create composite unique index on (created_by, name)
    # This enforces uniqueness per user, not globally
    op.create_index(
        'ix_teams_created_by_name',
        table_name='teams',
        columns=['created_by', 'name'],
        unique=True
    )


def downgrade() -> None:
    # Step 1: Drop the composite index
    op.drop_index('ix_teams_created_by_name', table_name='teams')

    # Step 2: Restore the global unique index on name
    op.create_index(
        'ix_teams_name',
        table_name='teams',
        columns=['name'],
        unique=True
    )