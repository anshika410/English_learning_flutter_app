# Ella — Voice-First English Learning App

Ella is a voice-first English learning app for Indian students built by NavGurukul. Students speak to an AI tutor named **Zoe** — no typing required. The app uses on-device speech recognition, AI-powered conversation, and text-to-speech to create a natural, low-pressure speaking practice experience.

**Platform:** Android-first Flutter · **Org:** NavGurukul

---

## What Ella Does

- **Placement test** — Zoe has a short conversation to assess the student's English level (A1–C1)
- **Topic-based conversations** — Students pick a topic (Cricket, Bollywood, School Life, Food, Gaming, Dreams) and have a real conversation with Zoe
- **Free chat** — Open-ended conversation on anything
- **Real-time feedback** — Grammar corrections and vocabulary suggestions woven naturally into the conversation
- **Session summary** — After each session, students see what they did well, new words used, and what to practice next
- **Progress tracking** — Streak, level, and session history

## Who It's For

Indian school students (primarily Hindi-speaking) at A1–B1 English level who need speaking practice but don't have access to English-speaking environments. The app is designed to feel like chatting with a friendly buddy, not a formal test.

## Tech Stack

**Frontend:** Flutter (Android-first) · On-device Whisper STT · Piper TTS · DeepSeek LLM  
**Backend:** FastAPI · PostgreSQL · Docker · AWS EC2

## Design Prototype

Three things live at the same GitHub Pages URL — versioned and growing:

| What | URL | Description |
|------|-----|-------------|
| 📱 **Product v0** | [ella-v0.html](https://turbo-potato-r3e4wrj.pages.github.io/ella-v0.html) | Interactive HTML prototype of the full app flow |
| 🎨 **Design v1** | [ella-design-v1.html](https://turbo-potato-r3e4wrj.pages.github.io/ella-design-v1.html) | Figma-style user flow and design system |
| 🌐 **Live Web App** | [turbo-potato-r3e4wrj.pages.github.io](https://turbo-potato-r3e4wrj.pages.github.io) | Flutter web build (latest `feature/integration`) |

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

The backend is hosted on AWS EC2 (ap-south-1, t3.micro, Ubuntu 24.04), running via Docker Compose with PostgreSQL.

> Connection details and SSH access are kept private. Ask a team member for access.

> HTTPS via Cloudflare Tunnel or a subdomain of `navgurukul.org` is planned before production release.

### Deploying updates to EC2

SSH into the server using the team's shared key (ask a team member), then:

```bash
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
