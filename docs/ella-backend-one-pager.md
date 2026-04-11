# Ella Backend — One Pager

## What is Ella?
An English learning app for Indian learners with AI-powered speaking practice, dictation with spaced repetition, and vocabulary quizzes. STT/TTS run on-device; LLM tutoring via OpenAI/DeepSeek.

## Why a Backend?
- Progress is lost on uninstall (SharedPreferences only)
- API keys are bundled in the app (.env)
- No cross-device sync, no analytics, no user identity

## What We're Building

### Core Services

| Service | Purpose |
|---------|---------|
| **Auth** | Firebase Auth (already initialized in app) |
| **Progress Sync** | Leitner box state, vocabulary mastery, settings |
| **Session Store** | Speaking transcripts, fluency scores, corrections |
| **LLM Proxy** | Route OpenAI/DeepSeek calls through backend — manage keys, costs, rate limits |
| **Analytics** | Track engagement, fluency trends, weak words |

### Data Model

```
User → id, email, language, preferences, created_at
WordProgress → user_id, word_id, box(0-5), correct, wrong, last_seen
SpeakingSession → user_id, topic, transcript, wpm, cefr_level, duration, feedback
Conversation → user_id, session_id, messages[], llm_provider, tokens_used
```

### Architecture

```
┌──────────┐     HTTPS/JSON      ┌──────────────┐      ┌────────────┐
│  Flutter  │ ◄────────────────► │   FastAPI     │ ◄──► │ PostgreSQL │
│   App     │                    │   Backend     │      └────────────┘
└──────────┘                     │               │      ┌────────────┐
     │                           │  • Auth       │ ◄──► │   Redis    │
     │  Firebase Auth token      │  • Sync API   │      └────────────┘
     └──────────────────────────►│  • LLM Proxy  │      ┌────────────┐
                                 │  • Analytics  │ ◄──► │ OpenAI /   │
                                 └──────────────┘      │ DeepSeek   │
                                                        └────────────┘
```

### Tech Stack
- **Framework:** Python / FastAPI
- **Database:** PostgreSQL (data) + Redis (cache, rate limiting)
- **Auth:** Firebase Auth (reuse existing Firebase project)
- **Deploy:** Railway or Fly.io (~$25/mo to start)

### API Surface (v1)

```
POST   /auth/verify          — validate Firebase token, create/get user
GET    /progress              — fetch all word progress for user
PUT    /progress/:wordId      — update Leitner box state
POST   /sessions              — save a speaking session + feedback
GET    /sessions              — list past sessions with scores
POST   /chat                  — LLM proxy (replaces direct OpenAI calls)
GET    /analytics/summary     — fluency trend, words mastered, streak
```

### Rollout Plan

| Week | Milestone |
|------|-----------|
| 1 | FastAPI scaffold + Firebase Auth + PostgreSQL schema |
| 2 | Progress sync API + migrate SharedPreferences writes |
| 3 | LLM proxy + remove API keys from app |
| 4 | Session persistence + analytics endpoint |

### Cost Estimate (1,000 users)
- Hosting: ~$25/mo (Railway)
- PostgreSQL: ~$15/mo (managed)
- Redis: ~$10/mo
- OpenAI (gpt-4o-mini): ~$15-30/mo
- **Total: ~$65-80/mo**

### Key Wins
1. Users keep progress across reinstalls and devices
2. API keys are server-side only — no more secrets in the app
3. Fluency analytics over time — "you went from A2 → B1 in 4 weeks"
4. Swap LLM models without shipping app updates
5. Foundation for future features: leaderboards, classrooms, teacher dashboards
