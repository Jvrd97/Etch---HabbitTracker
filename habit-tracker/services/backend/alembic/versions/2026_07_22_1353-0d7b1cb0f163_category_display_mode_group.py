# [review:need-review] PHASE-01/15-category-display-mode-group
# summary: reversible migration adding categories.display_mode (default form) and categories.group
"""category display_mode group

Revision ID: 0d7b1cb0f163
Revises: 10abe04ed653
Create Date: 2026-07-22 13:53:31.149120+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0d7b1cb0f163'
down_revision: Union[str, None] = '10abe04ed653'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "categories",
        sa.Column(
            "display_mode",
            sa.String(length=20),
            nullable=False,
            server_default="form",
        ),
    )
    op.add_column(
        "categories",
        sa.Column("group", sa.String(length=100), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("categories", "group")
    op.drop_column("categories", "display_mode")
