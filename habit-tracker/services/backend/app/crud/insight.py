# [review:need-review] PHASE-01/25-ai-reports-history
# summary: + list_ai_reports (newest first) and get_ai_report by id
from sqlalchemy import select
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


async def list_ai_reports(db: AsyncSession) -> list[AIReport]:
    """All AI reports, newest first."""
    result = await db.execute(
        select(AIReport).order_by(AIReport.created_at.desc(), AIReport.id.desc())
    )
    return list(result.scalars().all())


async def get_ai_report(db: AsyncSession, report_id: int) -> AIReport | None:
    """One AI report by id, or None when absent."""
    return await db.get(AIReport, report_id)
