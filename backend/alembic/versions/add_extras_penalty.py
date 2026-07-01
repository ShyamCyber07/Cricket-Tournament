"""add extras_penalty to innings

Revision ID: add_extras_penalty
Revises: add_match_num_and_strat
Create Date: 2026-07-01 15:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'add_extras_penalty'
down_revision = 'add_match_num_and_strat'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('innings', sa.Column('extras_penalty', sa.Integer(), server_default='0', nullable=False))

def downgrade():
    op.drop_column('innings', 'extras_penalty')
