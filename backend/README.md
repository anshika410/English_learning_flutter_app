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
| POST | `/auth/signup` | — | Register new user |
| POST | `/auth/login` | — | Login, get JWT |
| GET | `/users/me` | ✓ | Get profile |
| PUT | `/users/me` | ✓ | Update profile |
| PUT | `/users/me/settings` | ✓ | Update focus settings |
| POST | `/llm/conversation-starter` | ✓ | Generate opener |
| POST | `/llm/conversation-turn` | ✓ | Send message, get reply |
| POST | `/llm/placement-turn` | ✓ | Placement conversation turn |
| POST | `/llm/session-analysis` | ✓ | End-of-session feedback |
| POST | `/conversations` | ✓ | Create session |
| GET | `/conversations` | ✓ | List past sessions |
| GET | `/conversations/:id` | ✓ | Get session |
| PUT | `/conversations/:id/complete` | ✓ | Mark complete |
| POST | `/conversations/:id/messages` | ✓ | Store a turn |
| GET | `/conversations/:id/messages` | ✓ | Get transcript |
| POST | `/placements` | ✓ | Save placement result |
| GET | `/placements/latest` | ✓ | Get latest level |
| GET | `/placements` | ✓ | Level history |
| GET | `/progress/summary` | ✓ | Stats overview |
| GET | `/health` | — | Health check |
