# Ella — Voice-First English Learning App

Voice-first English learning app for Indian students. Students speak to an AI tutor (Zoe) — no typing required.

**Platform:** Android-first Flutter · **Org:** NavGurukul

---

## For Claude / New Contributors — Read This First

Before reading any code, start here:

| Document | When to read it |
|---|---|
| [`docs/project-summary.md`](docs/project-summary.md) | Architecture, screen flow, key files, key patterns — read once to orient yourself |
| [`docs/zoe-design-system.md`](docs/zoe-design-system.md) | Colour tokens, typography, shadows, component specs — check when touching UI |

**Rule of thumb:** Only open code files when you actually need to change something. The project summary gives you enough context to navigate without reading every screen upfront.

---

## Project Structure

```
ella_flutter/
├── frontend/              # Flutter app (Android-first)
│   ├── lib/
│   │   ├── screens/       # One file per screen
│   │   ├── widgets/       # Shared UI components
│   │   ├── services/      # TTS, STT, LLM, API abstractions
│   │   ├── providers/     # ChatProvider (conversation state)
│   │   ├── models/        # ChatMessage, PlacementResult, etc.
│   │   └── theme/         # EllaColors + EllaTheme
│   ├── assets/
│   │   ├── mascot-animations/   # Zoe .webp animations
│   │   ├── chillax/             # Chillax font files
│   │   ├── piper_voices/        # Piper TTS voice models
│   │   ├── whisper/             # Whisper STT model
│   │   └── prompts/             # LLM prompt markdown files
│   └── android/                 # Android-specific config
├── backend/               # FastAPI backend
│   ├── app/
│   │   ├── core/          # Config, DB, auth, deps
│   │   ├── models/        # SQLAlchemy ORM models
│   │   ├── schemas/       # Pydantic request/response schemas
│   │   ├── routers/       # Route handlers (18 endpoints)
│   │   └── services/      # LLM service
│   ├── migrations/        # Alembic migrations
│   ├── Dockerfile
│   └── docker-compose.yml
└── docs/                  # Architecture and design docs
```

---

## Running the Frontend

```bash
cd frontend
flutter pub get
flutter run
```

Requires a `.env` file inside `frontend/` with LLM API keys. Copy from `.env.example`:

```bash
cp frontend/.env.example frontend/.env
# Fill in DEEPSEEK_API_KEY
```

---

## Running the Backend

### With Docker (recommended)

```bash
cd backend
cp .env.example .env
# Fill in DEEPSEEK_API_KEY and JWT_SECRET
docker compose up -d
```

API available at `http://localhost:8000`
Docs at `http://localhost:8000/docs`

### Without Docker

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

---

## Production Backend

The backend is hosted on AWS EC2:

- **URL:** `http://13.233.132.240:8000`
- **Health check:** `http://13.233.132.240:8000/health`
- **API docs:** `http://13.233.132.240:8000/docs`
- **Instance:** `ella-zoe-backend` (t3.micro, Ubuntu 24.04, ap-south-1)
- **Runs via:** Docker Compose with PostgreSQL

> HTTPS via Cloudflare Tunnel or a subdomain of `navgurukul.org` is planned before production release.

### Deploying updates to EC2

```bash
# SSH into the server
ssh -i ~/Downloads/ella-zoe-key.pem -o ServerAliveInterval=60 ubuntu@13.233.132.240

# Pull latest code and restart
cd ~/ella_flutter && git pull
cd backend && docker compose down && docker compose up -d
```

---

## API Overview

**18 endpoints total** across 6 routers.

| Category | Endpoints | Flutter integrated |
|----------|-----------|-------------------|
| Auth | `POST /auth/anonymous` | ✅ |
| Users | `GET /users/me`, `PUT /users/me`, `PUT /users/me/settings` | ✅ profile, ❌ settings |
| Placements | `POST /placements`, `GET /placements/latest`, `GET /placements` | ✅ save + latest |
| Conversations | `POST`, `GET`, `GET /:id`, `PUT /:id/complete`, `POST /:id/messages`, `GET /:id/messages` | ❌ not yet |
| LLM (backend proxy) | `POST /llm/placement-turn`, `/conversation-turn`, `/conversation-starter`, `/session-analysis` | ❌ app calls DeepSeek directly |
| Progress | `GET /progress/summary` | ❌ not yet |

Full endpoint reference: [`backend/README.md`](backend/README.md)

---

## Branches

| Branch | Purpose |
|--------|---------|
| `main` | Stable |
| `feature/integration` | Latest working code |
| `feature/backend-integration` | Backend API wiring (active) |

---

## Key Services (Flutter)

| Service | File | Purpose |
|---------|------|---------|
| `ApiService` | `lib/services/api_service.dart` | All backend HTTP calls + JWT auth |
| `LlmService` | `lib/services/llm_service.dart` | Direct DeepSeek/OpenAI calls |
| `NativeSttService` | `lib/services/native_stt_service.dart` | Android native STT |
| `TtsManager` | `lib/services/tts_manager.dart` | Piper + system TTS |
| `UserPrefsService` | `lib/services/user_prefs_service.dart` | Local SharedPreferences |
