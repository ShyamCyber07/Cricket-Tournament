"""add fcm notifications infra

Revision ID: add_fcm_notifications_infra
Revises: add_squad_lock_and_umpire2_to_matches
Create Date: 2026-07-09 17:45:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'add_fcm_notifications_infra'
down_revision = 'add_squad_lock_and_umpire2_to_matches'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # 1. Modify notifications table
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = [col['name'] for col in inspector.get_columns('notifications')]
    
    if 'payload' not in columns:
        op.add_column('notifications', sa.Column('payload', sa.String(), nullable=True))
    if 'updated_at' not in columns:
        op.add_column('notifications', sa.Column('updated_at', sa.DateTime(), nullable=True))
        
    # 2. Create device_tokens table
    tables = inspector.get_table_names()
    if 'device_tokens' not in tables:
        op.create_table('device_tokens',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('user_id', sa.UUID(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
            sa.Column('fcm_token', sa.String(), nullable=False),
            sa.Column('device_name', sa.String(), nullable=True),
            sa.Column('platform', sa.String(), nullable=True),
            sa.Column('last_seen', sa.DateTime(), server_default=sa.func.now(), nullable=False),
            sa.Column('is_active', sa.Boolean(), server_default='true', nullable=False),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('fcm_token')
        )

def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    
    # 1. Drop device_tokens table
    tables = inspector.get_table_names()
    if 'device_tokens' in tables:
        op.drop_table('device_tokens')
        
    # 2. Drop columns from notifications
    columns = [col['name'] for col in inspector.get_columns('notifications')]
    if 'payload' in columns:
        op.drop_column('notifications', 'payload')
    if 'updated_at' in columns:
        op.drop_column('notifications', 'updated_at')
