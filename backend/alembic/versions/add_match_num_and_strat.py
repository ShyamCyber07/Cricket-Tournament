"""add match_number and strategy

Revision ID: add_match_num_and_strat
Revises: 49ccc345b8c4
Create Date: 2026-07-01 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'add_match_num_and_strat'
down_revision = '49ccc345b8c4'
branch_labels = None
depends_on = None

def upgrade():
    # add columns to matches
    op.add_column('matches', sa.Column('match_number', sa.Integer(), nullable=True))
    # add columns to match_squads
    op.add_column('match_squads', sa.Column('batting_order', sa.Integer(), nullable=True))
    op.add_column('match_squads', sa.Column('bowling_preference', sa.Integer(), nullable=True))

def downgrade():
    op.drop_column('match_squads', 'bowling_preference')
    op.drop_column('match_squads', 'batting_order')
    op.drop_column('matches', 'match_number')
