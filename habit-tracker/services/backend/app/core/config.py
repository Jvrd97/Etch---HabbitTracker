# [review:need-review] PHASE-01/26-llm-cli-backend
# summary: added LLM_BACKEND setting (cli | api; empty = auto-detect)
from typing import Literal

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Настройки приложения.
    Все параметры можно переопределить через переменные окружения.
    """

    # Database
    POSTGRES_USER: str = "habit_user"
    POSTGRES_PASSWORD: str = "habit_pass"
    POSTGRES_HOST: str = "localhost"
    POSTGRES_PORT: str = "5432"
    POSTGRES_DB: str = "habit_tracker"

    # Auth: empty string disables auth (dev mode, logs a warning)
    API_KEY: str = ""

    # AI insights: empty string disables the api backend (endpoint returns 503)
    ANTHROPIC_API_KEY: str = ""

    # LLM backend: "cli" (claude CLI binary) or "api" (Anthropic API).
    # Empty = auto: cli when no API key and the binary is found, else api.
    LLM_BACKEND: Literal["", "cli", "api"] = ""

    # API
    API_V1_PREFIX: str = "/api/v1"
    PROJECT_NAME: str = "Habit Tracker API"
    VERSION: str = "1.0.0"

    @property
    def DATABASE_URL(self) -> str:
        """Синхронный URL для Alembic"""
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    @property
    def ASYNC_DATABASE_URL(self) -> str:
        """Асинхронный URL для SQLAlchemy"""
        return f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
