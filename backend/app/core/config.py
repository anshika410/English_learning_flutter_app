from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # SQLite by default — zero setup, no cost.
    # To upgrade to PostgreSQL, just change this to:
    #   postgresql+asyncpg://user:password@host:5432/zoe
    database_url: str = "sqlite+aiosqlite:///./zoe.db"
    jwt_secret: str = "change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30
    frontend_url: str = "http://localhost:3000"
    deepseek_api_key: str = ""
    deepseek_base_url: str = "https://api.deepseek.com/v1"
    deepseek_model: str = "deepseek-chat"
    llm_rate_limit_per_minute: int = 30
    # Set to false in production to hide /docs and /redoc
    docs_enabled: bool = False
    # Admin dashboard secret key — set in .env
    admin_secret_key: str = "change-me-admin-key"
    # Reverse Proxy CORS Toggle
    # Set to True if Nginx/Cloudflare already adds 'Access-Control-Allow-Origin' to avoid duplicate headers in production
    disable_cors: bool = False
    
    google_web_client_id: str = ""
    google_android_client_id: str = ""
    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
