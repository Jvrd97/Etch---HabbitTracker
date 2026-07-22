# [review:need-review] PHASE-01/24-ai-insights-endpoint-button
# summary: CRUD for ai_reports (create persisted insight report)
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AIReport


async def create_ai_report(
    db: AsyncSession,
    *,
    period_days: int,
    content: str,
    model: str,
) -> AIReport:
    """Persist a generated AI insight report."""
    report = AIReport(period_days=period_days, content=content, model=model)
    db.add(report)
    await db.commit()
    await db.refresh(report)
    return report
