# [review:need-review] PHASE-01/27-streak-mode-endpoint
# summary: reversible migration adding categories.streak_mode (build|avoid, default build)
"""category streak_mode

Revision ID: 5b3d8c9a1f27
Revises: 3f2a9c1b7e44
Create Date: 2026-07-22 18:30:00.000000+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "5b3d8c9a1f27"
down_revision: Union[str, None] = "3f2a9c1b7e44"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "categories",
        sa.Column(
            "streak_mode",
            sa.String(length=20),
            nullable=False,
            server_default="build",
        ),
    )


def downgrade() -> None:
    op.drop_column("categories", "streak_mode")
