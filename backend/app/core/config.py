from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # SQLite by default — zero setup, no cost.
    # To upgrade to PostgreSQL, just change this to:
    #   postgresql+asyncpg://user:password@host:5432/zoe
    database_url: str = "sqlite+aiosqlite:///./zoe.db"
    jwt_secret: str = "change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 43200
    deepseek_api_key: str = ""
    deepseek_base_url: str = "https://api.deepseek.com/v1"
    deepseek_model: str = "deepseek-chat"
    llm_rate_limit_per_minute: int = 30
    # Set to false in production to hide /docs and /redoc
    docs_enabled: bool = False
    # Admin dashboard secret key — set in .env
    admin_secret_key: str = "change-me-admin-key"
    # Set to true in production if reverse proxy (like Nginx) already handles CORS
    disable_cors: bool = False

    model_config = {"env_file": "backend/.env", "extra": "ignore"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
