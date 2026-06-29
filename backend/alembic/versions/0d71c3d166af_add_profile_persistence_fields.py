"""add_profile_persistence_fields

Revision ID: 0d71c3d166af
Revises: 06ed4a631074
Create Date: 2026-06-29 18:10:14.673402

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0d71c3d166af'
down_revision: Union[str, None] = '06ed4a631074'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create tournament_activities and tournament_requests if they do not exist
    # (Since SQLite might not have them but PostgreSQL might or might not, we check or just create them)
    # To be extremely safe, we create them if not exists
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()
    
    if 'tournament_activities' not in tables:
        op.create_table('tournament_activities',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('tournament_id', sa.UUID(), nullable=False),
            sa.Column('user_id', sa.UUID(), nullable=False),
            sa.Column('action', sa.String(), nullable=False),
            sa.Column('details', sa.String(), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['tournament_id'], ['tournaments.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id')
        )
        
    if 'tournament_requests' not in tables:
        op.create_table('tournament_requests',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('tournament_id', sa.UUID(), nullable=False),
            sa.Column('team_id', sa.UUID(), nullable=False),
            sa.Column('status', sa.String(), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.Column('updated_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['team_id'], ['teams.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['tournament_id'], ['tournaments.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id')
        )

    # 2. Add columns to users table
    columns = [c['name'] for c in inspector.get_columns('users')]
    
    with op.batch_alter_table('users', schema=None) as batch_op:
        if 'phone_number' not in columns:
            batch_op.add_column(sa.Column('phone_number', sa.String(), nullable=True))
        if 'city' not in columns:
            batch_op.add_column(sa.Column('city', sa.String(), nullable=True))
        if 'dob' not in columns:
            batch_op.add_column(sa.Column('dob', sa.String(), nullable=True))
        if 'batting_style' not in columns:
            batch_op.add_column(sa.Column('batting_style', sa.String(), nullable=True))
        if 'bowling_style' not in columns:
            batch_op.add_column(sa.Column('bowling_style', sa.String(), nullable=True))
        if 'player_type' not in columns:
            batch_op.add_column(sa.Column('player_type', sa.String(), nullable=True))
        if 'dominant_hand' not in columns:
            batch_op.add_column(sa.Column('dominant_hand', sa.String(), nullable=True))
        if 'default_jersey_number' not in columns:
            batch_op.add_column(sa.Column('default_jersey_number', sa.Integer(), nullable=True))
        if 'profile_photo_bytes' not in columns:
            batch_op.add_column(sa.Column('profile_photo_bytes', sa.LargeBinary(), nullable=True))


def downgrade() -> None:
    # Rollback changes
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()
    
    if 'tournament_requests' in tables:
        op.drop_table('tournament_requests')
    if 'tournament_activities' in tables:
        op.drop_table('tournament_activities')
        
    columns = [c['name'] for c in inspector.get_columns('users')]
    with op.batch_alter_table('users', schema=None) as batch_op:
        if 'profile_photo_bytes' in columns:
            batch_op.drop_column('profile_photo_bytes')
        if 'default_jersey_number' in columns:
            batch_op.drop_column('default_jersey_number')
        if 'dominant_hand' in columns:
            batch_op.drop_column('dominant_hand')
        if 'player_type' in columns:
            batch_op.drop_column('player_type')
        if 'bowling_style' in columns:
            batch_op.drop_column('bowling_style')
        if 'batting_style' in columns:
            batch_op.drop_column('batting_style')
        if 'dob' in columns:
            batch_op.drop_column('dob')
        if 'city' in columns:
            batch_op.drop_column('city')
        if 'phone_number' in columns:
            batch_op.drop_column('phone_number')
