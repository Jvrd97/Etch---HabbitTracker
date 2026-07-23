# [review:need-review] PHASE-01/34-duration-field-type
# summary: reversible migration adding DURATION to the fieldtype enum
"""field_type duration

Revision ID: a1c2d3e4f5a6
Revises: 5b3d8c9a1f27
Create Date: 2026-07-23 12:00:00.000000+00:00

"""
from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a1c2d3e4f5a6"
down_revision: Union[str, None] = "5b3d8c9a1f27"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# SQLAlchemy stores the enum *member name* (uppercase) as the PG label.
ENUM_NAME = "fieldtype"
NEW_LABEL = "DURATION"
KEEP_LABELS = ("TEXT", "NUMBER", "BOOLEAN", "DATE", "DATETIME", "TIME", "SELECT")


def upgrade() -> None:
    # ALTER TYPE ... ADD VALUE cannot run inside a transaction block; Alembic
    # wraps migrations in one, so open an autocommit block just for this.
    with op.get_context().autocommit_block():
        op.execute(f"ALTER TYPE {ENUM_NAME} ADD VALUE IF NOT EXISTS '{NEW_LABEL}'")


def downgrade() -> None:
    # Postgres cannot drop a single enum value, so recreate the type without it.
    # Fails by design if any field still uses DURATION (the USING cast rejects
    # the orphaned label) — remove those rows before downgrading.
    keep = ", ".join(f"'{label}'" for label in KEEP_LABELS)
    op.execute(f"ALTER TYPE {ENUM_NAME} RENAME TO {ENUM_NAME}_old")
    op.execute(f"CREATE TYPE {ENUM_NAME} AS ENUM ({keep})")
    op.execute(
        f"ALTER TABLE fields ALTER COLUMN field_type "
        f"TYPE {ENUM_NAME} USING field_type::text::{ENUM_NAME}"
    )
    op.execute(f"DROP TYPE {ENUM_NAME}_old")
