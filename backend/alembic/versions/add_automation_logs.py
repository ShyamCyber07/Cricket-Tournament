"""add automation logs

Revision ID: add_automation_logs
Revises: add_fcm_notifications_infra
Create Date: 2026-07-09 19:45:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'add_automation_logs'
down_revision = 'add_fcm_notifications_infra'
branch_labels = None
depends_on = None

def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()
    
    if 'automation_logs' not in tables:
        op.create_table('automation_logs',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('match_id', sa.UUID(), sa.ForeignKey('matches.id', ondelete='CASCADE'), nullable=False),
            sa.Column('event_type', sa.String(), nullable=False),
            sa.Column('recipient_id', sa.UUID(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=True),
            sa.Column('executed_at', sa.DateTime(), server_default=sa.func.now(), nullable=False),
            sa.PrimaryKeyConstraint('id')
        )

def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()
    
    if 'automation_logs' in tables:
        op.drop_table('automation_logs')
