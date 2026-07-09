# ⚠️ DEPRECATED — V1 Legacy Codebase

This `frontend/` folder is the **old v1 Flutter web codebase**. It is no longer maintained or used.

## What replaced it
- **New app:** `ella_app/` — the active Flutter codebase (Android + iOS + Web)
- **Backend:** `backend/` — FastAPI backend, all LLM calls go through here
- **Prompts:** `backend/app/prompts/` — single source of truth for all LLM prompts

## Why this folder still exists
Kept for historical reference only. Do not make changes here.

## What was here
- `frontend/lib/services/llm_service.dart` — old client-side LLM calls (now handled by backend)
- `frontend/assets/prompts/` — old prompt files (now in `backend/app/prompts/`)
