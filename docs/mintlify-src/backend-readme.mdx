# Zoe Backend API

FastAPI backend for the Zoe English learning app.

## Stack
- **FastAPI** + **Uvicorn** — async web framework
- **SQLAlchemy 2 (async)** + **asyncpg** — database ORM
- **PostgreSQL** — primary database
- **Alembic** — migrations
- **python-jose** — JWT auth
- **httpx** — async HTTP client for LLM proxy

## Project Structure

```
backend/
├── app/
│   ├── core/
│   │   ├── config.py       # Settings from .env
│   │   ├── database.py     # Async SQLAlchemy engine + session
│   │   ├── security.py     # Password hashing + JWT
│   │   └── deps.py         # FastAPI dependencies (auth)
│   ├── models/             # SQLAlchemy ORM models
│   ├── schemas/            # Pydantic request/response schemas
│   ├── routers/            # Route handlers
│   │   ├── auth.py         # POST /auth/signup, /auth/login
│   │   ├── users.py        # GET/PUT /users/me
│   │   ├── llm.py          # POST /llm/* (proxy to DeepSeek)
│   │   ├── conversations.py
│   │   ├── placements.py
│   │   └── progress.py
│   ├── services/
│   │   └── llm_service.py  # LLM API calls + prompt rendering
│   └── main.py             # App entry point
├── migrations/             # Alembic migrations
├── requirements.txt
├── alembic.ini
├── Dockerfile
└── docker-compose.yml
```

## Quick Start

### 1. Copy env file
```bash
cp backend/.env.example backend/.env
# Fill in DEEPSEEK_API_KEY and JWT_SECRET
```

### 2. Run with Docker
```bash
cd backend
docker-compose up --build
```

API available at `http://localhost:8000`  
Docs at `http://localhost:8000/docs`

### 3. Run locally (without Docker)

```bash
# Create virtualenv
python -m venv .venv
source .venv/bin/activate

# Install deps
pip install -r backend/requirements.txt

# Start Postgres separately, then:
cd backend
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/anonymous` | — | Silent device-based login. Automatically generates a persistent JWT token and user record from the device UUID on startup. |
| GET | `/users/me` | ✓ | Retrieve authenticated student profile details. |
| PUT | `/users/me` | ✓ | Update profile info (name, age, location) extracted from conversations. |
| PUT | `/users/me/settings` | ✓ | Update student coaching settings (grammar, vocabulary, and fluency priorities). |
| POST | `/llm/conversation-starter` | ✓ | Generates a friendly topic-based opener from Zoe. |
| POST | `/llm/conversation-turn` | ✓ | Send user spoken message to Zoe, receive reply and grammar corrections. |
| POST | `/llm/placement-turn` | ✓ | Executes a turn in the voice placement screening test. Evaluates speech CEFR level; returns Zoe's next response or complete assessment (`is_complete=True`). |
| POST | `/llm/session-analysis` | ✓ | Generates overall post-session encouraging feedback cards, best moment highlights, and skills grade. |
| POST | `/conversations` | ✓ | Create a new active voice chat session container. |
| GET | `/conversations` | ✓ | Retrieve user conversation history list. |
| GET | `/conversations/:id` | ✓ | Fetch specific conversation session metadata. |
| PUT | `/conversations/:id/complete` | ✓ | Conclude the session and log calculated speaking duration. |
| POST | `/conversations/:id/messages` | ✓ | Persist individual spoken message bubble, corrections, and latency metrics to database history. |
| GET | `/conversations/:id/messages` | ✓ | Retrieve transcript history of a conversation session. |
| POST | `/placements` | ✓ | Save placement test CEFR level, highlights, interests, and transcript. |
| GET | `/placements/latest` | ✓ | Fetch latest active CEFR level placement details. |
| GET | `/placements` | ✓ | Retrieve full level history of all completed placement tests. |
| GET | `/progress/summary` | ✓ | Fetch aggregated learning statistics (minutes spoken, session completion rates). |
| GET | `/health` | — | Basic system health check. |
