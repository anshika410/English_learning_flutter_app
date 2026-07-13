# Ella Prompt Architecture — Complete Documentation

## Overview

There are **12 prompt files** across 4 categories:
- 3 Dynamic Templates (assembled at runtime with variables)
- 6 Static Level Profiles (loaded as-is, no variables)
- 3 Simulator-Only (not used by live app)
- 1 Hardcoded in Python (no file)

---

## DIAGRAM

```
USER OPENS APP AND CHATS
│
├── PLACEMENT FLOW (first time)
│   └── placement-check-prompt.md
│       + {{NAME}} + {{AGE}}
│       → DeepSeek → REPLY: or JSON assessment
│
├── CONVERSATION TURN (every turn)
│   └── conversation-prompt.md  ← shell template
│       + {{LEVEL_BLOCK}}       ← from profile-A0/A1/A2/B1/B2/C1.md
│       + {{UNITNAME}}          ← from curriculum_data.py
│       + {{UNITFOCUS}}         ← from curriculum_data.py
│       + {{TARGETS}}           ← skill IDs + text for this session
│       + {{ELICITATION}}       ← HOW to elicit those skills
│       + {{STUDENT_MEMORY}}    ← facts about learner from DB
│       + {{CURRENT_TURN}}      ← turn number (1-6)
│       → DeepSeek → Zoe's reply
│
├── SESSION END (after conversation completes)
│   └── end-result-prompt.md
│       + {{LEVEL}}             ← learner's CEFR level
│       + {{UNIT_LABEL}}        ← current unit name
│       + {{TOPIC}}             ← session topic
│       + {{TARGET_SKILLS}}     ← skill IDs aimed at this session
│       + {{FULL_TRANSCRIPT}}   ← full conversation text
│       → DeepSeek → JSON (scores, best moment, state changes)
│
└── CORRECTION HIGHLIGHT (separate call after each turn)
    └── Hardcoded in llm_service.py (extract_correction_highlight)
        + transcript injected inline
        → DeepSeek → JSON (student_said, corrected, highlight_word)
```

---

## CATEGORY 1 — Dynamic Templates (live app)

### 1. `conversation-prompt.md`
**What it does:** Main system prompt for every conversation turn. The shell that brings everything together.

**Type:** Dynamic template — 7 variables substituted at runtime

**Variables:**
| Variable | Source | Example |
|----------|--------|---------|
| `{{LEVEL_BLOCK}}` | profile-XX.md file | "LEVEL: A0. Your role: ECHO-BUILDER..." |
| `{{UNITNAME}}` | curriculum_data.py → active unit | "First words" |
| `{{UNITFOCUS}}` | curriculum_data.py → active unit | "Naming the things I can see." |
| `{{TARGETS}}` | curriculum_data.py → due_next skills | "- [U1-VOC-01] I can name colours..." |
| `{{ELICITATION}}` | curriculum_data.py → plan_text() | "Ask: what colour is your bag?" |
| `{{STUDENT_MEMORY}}` | DB → user.persona_memory | "- Likes cricket\n- Lives in Delhi" |
| `{{CURRENT_TURN}}` | turn counter | "3" |

**Used in:** `llm_service.py → send_conversation_turn()`

**Final prompt size:** ~800-1200 words depending on level and memory

---

### 2. `placement-check-prompt.md`
**What it does:** Runs the placement screening. Zoe chats naturally for 5-9 turns to assess the learner's CEFR level without them knowing they're being tested.

**Type:** Dynamic template — 2 variables substituted at runtime

**Variables:**
| Variable | Source | Example |
|----------|--------|---------|
| `{{NAME}}` | onboarding form | "Kavya" |
| `{{AGE}}` | onboarding form | "14" |

**Used in:** `llm_service.py → send_placement_turn()`

**Output:** Either `REPLY: <question>` (still in conversation) OR JSON assessment with level, confidence, interests

---

### 3. `end-result-prompt.md`
**What it does:** Post-session analysis. After conversation ends, scores each targeted skill, extracts best moment, correction, memory facts.

**Type:** Dynamic template — 5 variables substituted at runtime

**Variables:**
| Variable | Source | Example |
|----------|--------|---------|
| `{{LEVEL}}` | user.level from DB | "A1" |
| `{{UNIT_LABEL}}` | current unit name | "Finding My Voice" |
| `{{TOPIC}}` | session topic | "My school" |
| `{{TARGET_SKILLS}}` | skill IDs aimed at session | "- U1-VOC-01: I can name colours..." |
| `{{FULL_TRANSCRIPT}}` | all messages joined | "ZOE: Hi! STUDENT: Hello..." |

**Used in:** `llm_service.py → analyze_and_grade_session()`

**Output:** JSON with scores (0-1 confidence per skill), best_moment, correction_highlight, state_changes

---

## CATEGORY 2 — Static Level Profiles (live app)

These 6 files define **how Zoe behaves** at each CEFR level. Loaded at server startup into `_LEVEL_BLOCKS` dict. Injected into `conversation-prompt.md` as `{{LEVEL_BLOCK}}`.

**No variables. Edit file → behavior changes immediately after redeploy.**

### `profile-A0.md` — ECHO-BUILDER
- Role: Repeat-after-me teacher
- Length: 3–6 words per sentence
- Only yes/no and this-or-that questions
- Must ask learner to repeat words
- Accept Hindi, reply with English word

### `profile-A1.md` — CARRIER
- Role: Carry the conversation
- Length: 8–18 words per turn
- Accept fragments, scaffold one extension
- No correction, only natural recasting

### `profile-A2.md` — BRIDGE-BUILDER
- Role: Turn fragments into real conversation
- Length: 10–22 words per turn
- Simple open questions now allowed
- Occasional echo of corrected form

### `profile-B1.md` — SPACE-CREATOR
- Role: Talk less, learner talks more
- Length: 12–35 words per turn
- Open questions for reasons/opinions
- Gentle nudge correction only

### `profile-B2.md` — SPARRING PARTNER
- Role: Give learner something to push against
- Length: 15–40 words per turn
- Take positions, disagree playfully
- Invite register shifts

### `profile-C1.md` — PEER
- Role: Genuinely interesting conversation partner
- 2–3 sentences per turn
- Abstract/philosophical topics
- Precision feedback on word choice

---

## CATEGORY 3 — Simulator-Only (NOT used by live app)

These files exist for the loop simulator at `/v2/conversation-flow/`. They are fetched via `/admin/prompts` and displayed in the Glass Box panel.

### `base-prompt.md`
Zoe's identity and absolute rules. In the simulator this is the "Base Prompt" layer. **In the live app, these rules are duplicated inside `conversation-prompt.md` directly.**

### `conv-unit-framing.md`
The unit/skill framing section. **In the live app, this content is baked into `conversation-prompt.md` directly.** This file is the standalone version used by the simulator's Client (Mock) mode.

### `zoe-judge-prompt.md`
QA audit prompt. Scores Zoe's behavior on 10 dimensions (warmth, turn length, question stacking, escalation, etc.). **Only used in the simulator's Judge tab.** Never sent to DeepSeek in the live app.

---

## CATEGORY 4 — Hardcoded in Python (no file)

### `_STARTER_PROMPT` (in `llm_service.py`)
Generates Zoe's opening line for a new conversation. Short, rarely changes, so it stayed inline. Produces a 1-2 sentence starter + `TITLE: <header>`.

---

## Key Relationships

```
conversation-prompt.md
    CONTAINS the rules from base-prompt.md (duplicated inline)
    CONTAINS conv-unit-framing.md content (duplicated inline)
    INJECTS profile-XX.md as {{LEVEL_BLOCK}}

profile-*.md
    Single source of truth for level behavior
    Used by BOTH the live app AND the simulator Server tab
    Edit here → changes everywhere after redeploy

placement-check-prompt.md
    Completely standalone — does not use any other prompt
    Has its own level criteria, conversation rules, output format

end-result-prompt.md
    Completely standalone — post-session only
    Receives the full transcript, returns structured JSON

zoe-judge-prompt.md
    Simulator only — audits Zoe's behavior
    Never reaches production users
```

---

## Known Issues / Technical Debt

1. **`base-prompt.md` and `conv-unit-framing.md` are duplicated** — their content exists both as standalone files AND embedded inside `conversation-prompt.md`. If you edit `base-prompt.md`, the live app doesn't change (it reads from `conversation-prompt.md`). Only the simulator's Client tab would change.

2. **A0 profile compliance** — `profile-A0.md` rules are written as instructions but the LLM drifts toward fluent responses. Needs few-shot examples added to improve compliance.

3. **`_STARTER_PROMPT` is hardcoded** — should eventually be moved to a `starter-prompt.md` file for consistency.
