# [review:need-review] PHASE-01/24-ai-insights-endpoint-button
# summary: AIReport model — persisted AI insight reports (period_days, content, model)
from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.core.database import Base


class AIReport(Base):
    """
    AI insight report generated over a period of tracked data.

    Stores the rendered markdown report and the model that produced it.
    """

    __tablename__ = "ai_reports"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    period_days: Mapped[int] = mapped_column(Integer)
    content: Mapped[str] = mapped_column(Text)
    model: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    def __repr__(self) -> str:
        return f"<AIReport(id={self.id}, period_days={self.period_days})>"
