"""add tournament standings

Revision ID: add_tournament_standings
Revises: add_automation_logs
Create Date: 2026-07-09 21:20:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'add_tournament_standings'
down_revision = 'add_automation_logs'
branch_labels = None
depends_on = None

def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()
    
    if 'tournament_standings' not in tables:
        op.create_table('tournament_standings',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('tournament_id', sa.UUID(), sa.ForeignKey('tournaments.id', ondelete='CASCADE'), nullable=False),
            sa.Column('team_id', sa.UUID(), sa.ForeignKey('teams.id', ondelete='CASCADE'), nullable=False),
            sa.Column('played', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('won', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('lost', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('tied', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('no_result', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('points', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('runs_scored', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('overs_faced', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('runs_conceded', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('overs_bowled', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('net_run_rate', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('is_qualified', sa.Boolean(), nullable=False, server_default='false'),
            sa.PrimaryKeyConstraint('id')
        )

def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()
    
    if 'tournament_standings' in tables:
        op.drop_table('tournament_standings')
