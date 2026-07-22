# [review:need-review] PHASE-01/24-ai-insights-endpoint-button
# summary: reversible migration adding ai_reports table (period_days, content, model, created_at)
"""ai_reports table

Revision ID: 3f2a9c1b7e44
Revises: 0d7b1cb0f163
Create Date: 2026-07-22 16:00:00.000000+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "3f2a9c1b7e44"
down_revision: Union[str, None] = "0d7b1cb0f163"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "ai_reports",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("period_days", sa.Integer(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("model", sa.String(length=100), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_ai_reports_id"), "ai_reports", ["id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_ai_reports_id"), table_name="ai_reports")
    op.drop_table("ai_reports")
