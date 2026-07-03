"""add squad lock and umpire2 to matches

Revision ID: add_squad_lock_and_umpire2_to_matches
Revises: add_extras_penalty
Create Date: 2026-07-02 22:38:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'add_squad_lock_and_umpire2_to_matches'
down_revision = 'add_extras_penalty'
branch_labels = None
depends_on = None

def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = [col['name'] for col in inspector.get_columns('matches')]
    
    if 'team1_squad_locked' not in columns:
        op.add_column('matches', sa.Column('team1_squad_locked', sa.Boolean(), server_default='false', nullable=False))
    if 'team2_squad_locked' not in columns:
        op.add_column('matches', sa.Column('team2_squad_locked', sa.Boolean(), server_default='false', nullable=False))
    if 'umpire2_name' not in columns:
        op.add_column('matches', sa.Column('umpire2_name', sa.String(), nullable=True))

def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = [col['name'] for col in inspector.get_columns('matches')]
    
    if 'team1_squad_locked' in columns:
        op.drop_column('matches', 'team1_squad_locked')
    if 'team2_squad_locked' in columns:
        op.drop_column('matches', 'team2_squad_locked')
    if 'umpire2_name' in columns:
        op.drop_column('matches', 'umpire2_name')
