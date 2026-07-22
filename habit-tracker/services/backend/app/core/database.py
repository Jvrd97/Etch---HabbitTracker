# [review:need-review] PHASE-01/13-backend-uv-mypy-ruff
# summary: typed DeclarativeBase + AsyncGenerator return type on get_db (mypy --strict)
from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

# Async engine. SQL echo is off: statement logging would leak journal text
# and other personal values into logs (project rule: no PII in logs).
engine = create_async_engine(
    settings.ASYNC_DATABASE_URL,
    echo=False,
    future=True,
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    """Typed declarative base for all ORM models."""


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency providing a DB session.

    Commits on success, rolls back on error, always closes the session.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
