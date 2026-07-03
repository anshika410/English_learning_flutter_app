from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.openapi.docs import get_redoc_html
from .core.database import engine, Base
from .core.config import get_settings
from .routers import auth, users, llm, conversations, placements, progress
from .routers.admin import router as admin_router
from .routers.admin_metrics import router as admin_metrics_router
# from .routers.accent import router as accent_router, load_accent_model  # disabled — requires numpy/tensorflow

# Import all models so SQLAlchemy registers them before create_all
from .models import user, placement, conversation, message, session_analysis  # noqa: F401


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield


from fastapi.openapi.utils import get_openapi

settings = get_settings()

app = FastAPI(
    title="Ella API",
    description="Backend for the Ella English learning app",
    version="1.0.0",
    lifespan=lifespan,
    root_path="/api",
    servers=[
        {"url": "https://ella.navgurukul.org/api", "description": "Production Server"},
        {"url": "http://localhost:8000/api", "description": "Local Server"}
    ],
    # Hide docs unless explicitly enabled via DOCS_ENABLED=true in .env
    docs_url="/docs" if settings.docs_enabled else None,
    redoc_url=None,  # Disable default ReDoc to use custom stable CDN URL below
    openapi_url="/openapi.json" if settings.docs_enabled else None,
)

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    openapi_schema["servers"] = [
        {"url": "https://ella.navgurukul.org/api", "description": "Production Server"},
        {"url": "http://localhost:8000/api", "description": "Local Server"}
    ]
    # Inject 10-year demo token as x-default for Bearer auth
    if "components" in openapi_schema and "securitySchemes" in openapi_schema["components"]:
        if "HTTPBearer" in openapi_schema["components"]["securitySchemes"]:
            openapi_schema["components"]["securitySchemes"]["HTTPBearer"]["x-default"] = (
                "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI1N2U0NDg0NC04YWRiLTQyNTgtYWI4Mi05"
                "MWNmNDUxZTQ4OGEiLCJleHAiOjIwOTY4Njg2Njh9._oyjz0enX_sLYvidUm4EUMq5oTNUpxZmowoxIf5J7dc"
            )
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi


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
app.include_router(conversations.router, prefix="/session")
app.include_router(conversations.router, prefix="/sessions")
app.include_router(placements.router)
app.include_router(progress.router)
app.include_router(admin_router)
app.include_router(admin_metrics_router)


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
