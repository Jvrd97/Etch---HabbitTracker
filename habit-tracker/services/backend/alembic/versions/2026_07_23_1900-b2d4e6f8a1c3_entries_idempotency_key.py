# [review:need-review] PHASE-01/39-server-idempotency-key-entries
# summary: reversible migration adding nullable unique entries.idempotency_key
"""entries idempotency key

Revision ID: b2d4e6f8a1c3
Revises: a1c2d3e4f5a6
Create Date: 2026-07-23 19:00:00.000000+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b2d4e6f8a1c3"
down_revision: Union[str, None] = "a1c2d3e4f5a6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE = "entries"
COLUMN = "idempotency_key"
INDEX = "ix_entries_idempotency_key"


def upgrade() -> None:
    op.add_column(TABLE, sa.Column(COLUMN, sa.String(length=255), nullable=True))
    # Unique so a replayed create collides; nullable rows are exempt in Postgres
    # (multiple NULLs allowed), keeping keyless creates unconstrained.
    op.create_index(INDEX, TABLE, [COLUMN], unique=True)


def downgrade() -> None:
    op.drop_index(INDEX, table_name=TABLE)
    op.drop_column(TABLE, COLUMN)
