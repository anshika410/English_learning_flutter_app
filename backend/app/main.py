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


from fastapi.responses import HTMLResponse

PRIVACY_POLICY_HTML = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Privacy Policy - Ella</title>
    <style>
        body { font-family: sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; line-height: 1.6; }
        ul { margin-top: 0; }
    </style>
</head>
<body>
    <h1>Privacy Policy - Ella</h1>
    <p><strong>Last updated: July 20, 2026</strong></p>
    <p>Ella is committed to protecting your privacy. This privacy policy describes how we collect, use, process, and protect your personal data in connection with the Ella English learning application.</p>
    
    <h2>1. Information We Collect</h2>
    <p>To provide a personalized learning experience, we collect the following types of information:</p>
    <ul>
        <li><strong>Account & Profile Data:</strong> We collect your name, age, and email address.</li>
        <li><strong>Voice & Conversation Data:</strong> We collect voice recordings when you interact with the app. These recordings are transcribed into text to facilitate conversation.</li>
        <li><strong>Device & Usage Data:</strong> We track your learning progress, CEFR level, and interactions within the app to tailor the curriculum to your needs.</li>
    </ul>

    <h2>2. How We Use Information</h2>
    <p>Your data is used solely to provide and improve the Ella learning experience:</p>
    <ul>
        <li><strong>Conversational AI:</strong> Your voice transcripts are processed by Large Language Models (AI) to simulate real-time conversations, grade your language proficiency, and provide feedback.</li>
        <li><strong>Identity Protection:</strong> While we securely store your full name for account management purposes, we restrict our AI services and the application interface to strictly use only your <strong>first name</strong>. This ensures your personal identity is minimized during AI conversation simulations and throughout your learning experience.</li>
        <li><strong>Personalization:</strong> We use your age and learning history to curate relevant conversation topics and adapt the difficulty of the curriculum.</li>
    </ul>

    <h2>3. Third-Party Services</h2>
    <p>To power our conversation features, we use third-party AI providers to process text transcripts. We do not share your full name or personal contact information with these AI providers. Your transcripts are sent securely and are used solely for generating conversational responses and language assessments.</p>

    <h2>4. Data Security and Deletion</h2>
    <p>We implement appropriate security measures to protect your information. You have the right to control your data:</p>
    <ul>
        <li>You can request complete data deletion at any time via the profile settings inside the app. Upon request, we will permanently delete your account, profile data, and conversation history.</li>
    </ul>

    <h2>5. Contact Us</h2>
    <p>If you have any questions or concerns about this privacy policy or your data, please contact our support team through the application.</p>
</body>
</html>"""


@app.get("/v2/privacypolicy", response_class=HTMLResponse, include_in_schema=False)
async def privacy_policy_v2():
    return PRIVACY_POLICY_HTML


@app.get("/privacypolicy", response_class=HTMLResponse, include_in_schema=False)
async def privacy_policy():
    return PRIVACY_POLICY_HTML


@app.get("/", include_in_schema=False)
async def root():
    if settings.docs_enabled:
        return RedirectResponse(url="/docs")
    return {"status": "ok", "message": "Ella API"}


@app.get("/health")
async def health():
    return {"status": "ok"}

