"""add_assigned_scorer_id_to_matches

Revision ID: 5bcdf48f4d4f
Revises: b2017fb6364a
Create Date: 2026-06-17 14:21:55.399655

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5bcdf48f4d4f'
down_revision: Union[str, None] = 'b2017fb6364a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = [col['name'] for col in inspector.get_columns('matches')]
    if 'assigned_scorer_id' not in columns:
        op.add_column('matches', sa.Column('assigned_scorer_id', sa.UUID(), nullable=True))
        op.create_foreign_key(
            'fk_matches_assigned_scorer_id',
            'matches', 'users',
            ['assigned_scorer_id'], ['id'],
            ondelete='SET NULL'
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    columns = [col['name'] for col in inspector.get_columns('matches')]
    if 'assigned_scorer_id' in columns:
        # Avoid dropping FK on dialects that do not support it or if it wasn't created by migrations
        try:
            op.drop_constraint('fk_matches_assigned_scorer_id', 'matches', type_='foreignkey')
        except Exception:
            pass
        op.drop_column('matches', 'assigned_scorer_id')
