from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Gramin Demo Bank"
    database_url: str = "sqlite:///./gramin.sqlite3"
    jwt_secret: str = "development-only-change-me"
    access_token_minutes: int = 60 * 24 * 7
    cors_origins: str = "*"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()

