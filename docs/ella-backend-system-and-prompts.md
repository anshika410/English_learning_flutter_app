Ella Backend System Design and Prompts


PART 1 — BACKEND SYSTEM ARCHITECTURE


Tech Stack
  Framework: FastAPI (Python)
  Database: PostgreSQL 16 (via Docker)
  ORM: SQLAlchemy (async)
  Auth: JWT Bearer tokens
  LLM: DeepSeek API (proxied through backend)
  Hosting: AWS EC2 (ap-south-1), Docker Compose
  Domain: ella.navgurukul.org/api


Routers (API modules)
  auth — anonymous device-based authentication
  users — profile read/update
  llm — LLM proxy (placement turn, conversation turn, conversation starter, session analysis)
  conversations — create, list, complete, messages
  placements — save and retrieve placement results
  progress — progress summary
  admin — admin stats and transcript viewer (key-protected)


Database Tables (current)
  users — id, device_id, name, age, location, level, level_label, grammar_focus, vocab_focus, fluency_focus, first_session_done, created_at
  placements — id, user_id, level, level_label, confidence, highlight, transcript_json, created_at
  conversations — id, user_id, topic, header_title, duration_seconds, session_type, quality, completed, created_at
  messages — id, conversation_id, role, content, correction, turn_number, stt_duration_ms, llm_duration_ms, tts_duration_ms, created_at
  session_analyses — id, conversation_id, analysis_json, created_at


API Endpoints

  POST /auth/anonymous
    Body: device_id
    Returns: access_token, user_id, is_new
    Creates or finds user by device_id, returns JWT

  GET /users/me
    Returns: user profile

  PUT /users/me
    Body: name, age, location (all optional)
    Updates user profile

  PUT /users/me/settings
    Body: grammar_focus, vocab_focus, fluency_focus
    Updates coaching preferences

  POST /llm/placement-turn
    Body: messages (array of role/content), name, age
    Returns: reply (if still chatting) or is_complete with level_code, level_name, etc.
    Proxies to DeepSeek with placement prompt

  POST /llm/conversation-starter
    Body: topic (optional)
    Returns: starter, header_title
    Generates opening line for a conversation

  POST /llm/conversation-turn
    Body: conversation_id, messages, topic, level, level_label, current_turn, grammar_focus, vocab_focus, fluency_focus
    Returns: reply, correction, conversation_complete
    Proxies to DeepSeek with conversation prompt

  POST /llm/session-analysis
    Body: conversation_id, messages, topic, level, level_label
    Returns: overall, best_moment, courage_or_motivation, try_next_time, transcript_notes
    Generates post-session analysis

  POST /conversations
    Body: topic (optional)
    Returns: conversation object with id

  GET /conversations
    Returns: list of user's conversations

  PUT /conversations/{id}/complete
    Body: duration_seconds, session_type
    Marks conversation as complete

  POST /conversations/{id}/messages
    Body: role, content, correction, stt_duration_ms, llm_duration_ms, tts_duration_ms, turn_number
    Stores a message

  GET /conversations/{id}/messages
    Returns: all messages for a conversation

  POST /placements
    Body: level, level_label, highlight, transcript_json
    Saves placement result and updates user level

  GET /placements/latest
    Returns: most recent placement for user

  GET /placements
    Returns: all placements for user

  GET /progress/summary
    Returns: progress summary for user

  GET /admin/stats?key=...
    Returns: total_users, total_sessions, completed_sessions, total_speaking_minutes, level_distribution, users list, recent_conversations

  GET /admin/conversations/{id}/transcript?key=...
    Returns: full message transcript for a conversation

  GET /admin/placements/{user_id}/transcript?key=...
    Returns: placement transcript for a user


Authentication Flow
  1. App starts, calls POST /auth/anonymous with device_id (UUID stored on device)
  2. Backend creates user if new, or finds existing user by device_id
  3. Returns JWT token (valid 30 days)
  4. All subsequent requests include Authorization: Bearer token header
  5. Token decoded on each request to identify user


LLM Proxy Flow
  1. App sends messages array to /llm/placement-turn or /llm/conversation-turn
  2. Backend loads prompt template from /app/assets/prompts/ folder
  3. Backend injects variables (level, topic, turn number, etc.) into prompt
  4. Backend calls DeepSeek API with system prompt + messages
  5. Backend parses LLM response (extracts REPLY: prefix, JSON output, etc.)
  6. Backend returns structured response to app

  Why proxy: keeps API keys server-side, allows prompt changes without app update, enables logging and rate limiting


Infrastructure
  EC2 instance: t3.micro, Ubuntu 24.04, 19GB disk
  Docker Compose: 2 containers (api + db)
  Nginx: reverse proxy with SSL (Let's Encrypt)
  Domain routing:
    ella.navgurukul.org/ — landing page
    ella.navgurukul.org/api/ — proxied to FastAPI on port 8000
    ella.navgurukul.org/admin/ — pilot dashboard
    ella.navgurukul.org/v1/ — Flutter web app
    ella.navgurukul.org/design/ — design system
    ella.navgurukul.org/v0/ — v0 prototype


---


PART 2 — PROMPTS CURRENTLY IN USE


PROMPT 1: Placement Check (placement-check-prompt.md)

Purpose: Zoe has a friendly conversation with a new student to quietly assess their CEFR level (A1 to C1). The student does not know they are being assessed.

Role: Zoe is a warm, curious friend meeting the student for the first time.

Key behaviours:
  Never reveals this is a test
  Asks age-appropriate questions
  Adapts difficulty based on responses (one rung at a time)
  Covers 4 probe targets: concrete self-description, past narrative, opinion + reason, extended description/hypothetical
  Minimum 5 turns, target 7, maximum 9

Level criteria:
  A1 (First Words) — single words, short phrases, mostly present tense, very limited vocab
  A2 (Finding My Voice) — simple sentences, mostly present with some past, everyday topics only
  B1 (Speaking Freely) — connected sentences with and/but/because, opinions with reasons, past tense mostly correct
  B2 (Almost Fluent) — fluent and spontaneous, varied tenses, can argue with reasons
  C1 (Fluent) — articulate, nuanced, handles abstract topics, near-natural flow

Important rules:
  Does not judge pronunciation or regional accent
  Treats Indian English features as variety, not error
  Handles code-switching warmly
  Handles silence with progressively simpler questions

Output: When confident, outputs JSON with level_code, level_name, level_description, confidence, evidence_summary, probe_targets_covered, turns_taken, notes_for_first_session


PROMPT 2: Conversation Turn (conversation-prompt.md)

Purpose: Zoe has a topic-based conversation with the student, coaching them at their level.

Variables injected: topic, level, level_label, current_turn, level_instructions, grammar_setting, vocabulary_setting, fluency_setting

Key behaviours:
  Stays in character as Zoe throughout
  Keeps responses short (1-3 sentences)
  Asks exactly one question per turn
  Matches vocabulary and complexity to student level
  Applies coaching settings (grammar feedback, vocabulary suggestions, fluency tracking)
  Closes conversation warmly at turn 6

Level-specific instructions:
  A1 — accept any attempt, celebrate every response, only present simple, familiar topics
  A2 — use salient recasts (model correct form naturally), ask about past events and opinions
  B1 — metalinguistic nudges, push for 60-second responses, offer vocabulary alternatives
  B2 — explicit correction when permitted, push for 4-part arguments, flag register mismatches
  C1 — peer mode, stylistic suggestions, expect idiomatic expression

Output: REPLY: prefix for spoken text. At turn 6, adds conversation_complete JSON.


PROMPT 3: Session Analysis (end-result-prompt.md)

Purpose: After conversation ends, analyzes the full transcript and generates a structured report for the student.

Variables injected: level, level_label, topic, full_transcript

Output JSON structure:
  overall — good, okay, or struggling
  best_moment — exact quote from student + why it was strong
  courage_or_motivation — specific moment of courage or warm encouragement
  try_next_time — one actionable skill + concrete example sentence
  transcript_notes — per-turn notes on what was strong and what could improve

Rules:
  Never uses "incorrect" or "wrong"
  For A1/A2: focuses on what they attempted and got right
  For B1+: includes grammar and vocabulary observations
  best_moment must be verbatim from transcript
