from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.openapi.docs import get_redoc_html
from .core.database import engine, Base
from .core.config import get_settings
from .routers import auth, users, llm, conversations, placements, progress, curriculum
from .routers.admin import router as admin_router
# from .routers.accent import router as accent_router, load_accent_model  # disabled — requires numpy/tensorflow

# Import all models so SQLAlchemy registers them before create_all
from .models import user, placement, conversation, message, session_analysis  # noqa: F401


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create tables on startup (use Alembic in production)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


settings = get_settings()

app = FastAPI(
    title="Ella API",
    description="Backend for the Ella English learning app",
    version="1.0.0",
    lifespan=lifespan,
    root_path="/api",
    # Hide docs unless explicitly enabled via DOCS_ENABLED=true in .env
    docs_url="/docs" if settings.docs_enabled else None,
    redoc_url=None,  # Disable default ReDoc to use custom stable CDN URL below
    openapi_url="/openapi.json" if settings.docs_enabled else None,
)

if not settings.disable_cors:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(llm.router)
app.include_router(conversations.router)
app.include_router(placements.router)
app.include_router(progress.router)
app.include_router(curriculum.router)
app.include_router(admin_router)


if settings.docs_enabled:
    @app.get("/redoc", include_in_schema=False)
    async def custom_redoc_html(req: Request):
        root_path = req.scope.get("root_path", "").rstrip("/")
        openapi_url = root_path + (app.openapi_url or "/openapi.json")
        return get_redoc_html(
            openapi_url=openapi_url,
            title=app.title + " - ReDoc",
            redoc_js_url="https://cdn.jsdelivr.net/npm/redoc@2.1.3/bundles/redoc.standalone.js",
        )


@app.get("/", include_in_schema=False)
async def root():
    if settings.docs_enabled:
        return RedirectResponse(url="/docs")
    return {"status": "ok", "message": "Ella API"}


@app.get("/health")
async def health():
    return {"status": "ok"}
