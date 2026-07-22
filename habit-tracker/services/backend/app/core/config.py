# [review:need-review] PHASE-01/24-ai-insights-endpoint-button
# summary: added ANTHROPIC_API_KEY setting (empty = AI insights disabled)
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

    # AI insights: empty string disables the feature (endpoint returns 503)
    ANTHROPIC_API_KEY: str = ""

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
