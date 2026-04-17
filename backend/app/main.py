from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from .core.database import engine, Base
from .core.config import get_settings
from .routers import auth, users, llm, conversations, placements, progress
from .routers.accent import router as accent_router, load_accent_model

# Import all models so SQLAlchemy registers them before create_all
from .models import user, placement, conversation, message, session_analysis  # noqa: F401


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create tables on startup (use Alembic in production)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    # Load accent classifier
    load_accent_model()
    yield


settings = get_settings()

app = FastAPI(
    title="Zoe API",
    description="Backend for the Zoe English learning app",
    version="1.0.0",
    lifespan=lifespan,
    # Hide docs unless explicitly enabled via DOCS_ENABLED=true in .env
    docs_url="/docs" if settings.docs_enabled else None,
    redoc_url="/redoc" if settings.docs_enabled else None,
    openapi_url="/openapi.json" if settings.docs_enabled else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(llm.router)
app.include_router(conversations.router)
app.include_router(placements.router)
app.include_router(progress.router)
app.include_router(accent_router)


@app.get("/", include_in_schema=False)
async def root():
    if settings.docs_enabled:
        return RedirectResponse(url="/docs")
    return {"status": "ok", "message": "Zoe API"}


@app.get("/health")
async def health():
    return {"status": "ok"}
