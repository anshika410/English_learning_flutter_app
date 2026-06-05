# ELLA — Finalized Build Specification

**Single source of truth for the development team.**
Consolidates: the app design (from the simulator), the agreed backend architecture (colleague's doc + review), the hardened database schema and RLS, the deterministic engine rules, and the open decisions still to confirm.

Status legend: ✅ **Locked** · 🟡 **Decide before coding** · 🔵 **Future / deferred**

---

## 0. The one principle everything hangs on ✅

> **LLMs only talk (Zoe) and score (judges). Plain, testable engine code makes every decision about a child's state.**
> No model ever writes `owned`, `emerging`, or `due_next`. The client never writes state either — only the engine (service role) does.

If a change ever violates this, it's wrong regardless of how convenient it is.

---

# PART A — APP DESIGN (from the simulator)

The simulator has two halves. In production they become two different surfaces.

## A.1 Child View — the Android app ✅

What the child actually uses. Voice-first, warm, no jargon, no scores shown.

| Element | Behaviour |
|---|---|
| **Zoe chat** | Child speaks → on-device STT → text → engine → Zoe reply → on-device TTS speaks it. A real spoken conversation, not a quiz. |
| **Garden** | The child-facing progress metaphor. Each skill maps to a `object` (a plant). Skills grow as they move locked → emerging → owned. Replaces the glass box's raw skill dots. |
| **Effort number** | One number the child sees: `times_spoken_total`. Only ever goes up. No streaks, no penalties. |
| **"Grew!" moment** | After a chat, the garden animates whatever changed state. This is the reward loop. |
| **Topic** | Chosen for them each chat (fresh, interest-matched). The child never picks from a list. |

**Persona by level (from the prompts):** A1/A2 Zoe is a *carrier* (she carries the conversation, one-word answers count). B1+ Zoe is a *space-creator* (she talks less, learner talks more). Never criticises at any level.

## A.2 Glass Box — teacher/parent dashboard + internal admin ✅

Everything the simulator exposed on the right. **Not shown to the child.** Splits into two audiences:

| Tab in simulator | Production home | Audience |
|---|---|---|
| Memory | Progress view (read-only) | Teacher/parent |
| Skills / Units | Progress detail | Teacher/parent |
| History | Session history | Teacher/parent |
| Judge / Both (dual-judge) | QA console | Internal only |
| Session log | QA / debugging | Internal only |
| due_next | QA / debugging | Internal only |
| Prompt (assembled) | Prompt debugging | Internal only |
| Edit Prompts | Admin prompt editor | Admin only 🟡 |
| LLM settings | Infra config (env, not UI) | Internal only |

---

# PART B — BACKEND ARCHITECTURE (agreed)

## B.1 What runs where ✅

```
PHONE (Flutter, budget Android)
  • sherpa-onnx STT + TTS   ── on-device, zero per-utterance cloud cost
  • Zoe chat UI + garden
  • optimistic local state (read-only mirror; never the source of truth)
        │  HTTPS (transcript text only)
        ▼
ENGINE API  (Supabase Edge Function, or small FastAPI service)
  deterministic code — THE HEART:
  • assemble Zoe prompt        • merge / promotion
  • due_next + topic pick      • level-up + unit-complete rules
  • connects as SERVICE ROLE (bypasses RLS) — the only writer of state
        │  reads/writes state            │ calls models
        ▼                                ▼
SUPABASE                            LLM PROXY (keys server-side)
  • Postgres + RLS                   • Zoe (conversation model)
  • Auth                             • Skill judge (scores state)
  • Storage (audio, if kept)         • Zoe judge (QA, sampled)
                                          │
                                          ▼
                                  Gemini / DeepSeek / etc.
```

**Locked decisions:**
- ✅ On-device voice (sherpa-onnx) — the cost-driving choice for India/budget Android.
- ✅ Engine is a distinct, unit-testable service — not buried in the app.
- ✅ All model calls go through a proxy; no key ever touches the phone.
- ✅ `memory_state` is overwritten (current snapshot); `session_logs` + `transcripts` accumulate (evidence trail). Different lifecycles on purpose.

## B.2 One chat, end to end ✅

1. **Start** — app requests start for `child_id` → engine reads `memory_state` → picks `due_next` + topic → assembles Zoe prompt → proxy (Zoe) → opening line → phone speaks it.
2. **Converse** — child speaks → STT → engine → proxy (Zoe) → reply → TTS → repeat.
3. **End** — app signals end → engine calls proxy (skill judge) → per-skill confidences → engine runs the deterministic merge → writes `memory_state`, `session_logs`, `transcripts` → returns `state_changes` → garden animates.
4. **Sometimes** — engine calls proxy (Zoe judge), sampled → writes `zoe_evals`. QA only; drives nothing.

---

# PART C — DATABASE SCHEMA (finalized SQL)

Run top to bottom. Incorporates every fix from review: CHECK constraints, `progression_model` on `memory_state`, a real home for topics, and the optional prompts table.

```sql
-- ============================================================
-- ELLA — Supabase schema (FINAL)
-- Run top-to-bottom. Postgres / Supabase.
-- ============================================================
create extension if not exists "pgcrypto";   -- for gen_random_uuid()

-- 1. STATIC REFERENCE: skill catalogue (skills + units)
create table skill_catalogue (
  skill_id        text primary key,            -- 'A1-VOC-01' or 'U1-GRA-01'
  level           text check (level in ('A1','A2','B1','B2','C1','C2')),  -- null for unit skills
  strand          text not null check (strand in ('VOC','GRA','FLU')),
  statement_text  text not null,               -- the "I can…" statement (never shown to child)
  object          text,                        -- garden plant shown to the child
  kind            text not null default 'flat' check (kind in ('flat','unit')),
  unit_step       text,                         -- '1'..'5' for unit skills
  unit_name       text,
  unit_focus      text,
  created_at      timestamptz default now()
);

-- 2. STATIC REFERENCE: topic bank (was missing — topics now have a home)
create table topics_catalogue (
  topic_id   uuid primary key default gen_random_uuid(),
  level      text not null check (level in ('A1','A2','B1','B2','C1','C2')),
  theme      text not null,
  topic      text not null,
  starters   text,
  is_active  boolean not null default true,
  created_at timestamptz default now()
);

-- 3. EDITABLE AI CONFIG (optional — keep if you want prompt changes without a deploy)
create table app_prompts (
  key        text primary key
               check (key in ('base','profileA1','profileB1','convSkill','convUnit','judge')),
  content    text not null,
  version    int not null default 1,
  updated_at timestamptz default now()
);

-- 4. CHILDREN: one row per learner (profile)
create table children (
  child_id       uuid primary key default gen_random_uuid(),
  auth_user_id   uuid references auth.users(id) on delete cascade,  -- child-is-the-user model (see open decision D1)
  name           text,
  age            int check (age between 3 and 19),
  grade          text,                          -- text: allows 'Grade 5' / 'Class 7'
  home_language  text default 'Hindi',
  interests      text,                          -- free text, feeds topic-picker
  created_at     timestamptz default now()
);

-- 5. MEMORY STATE: one row per child, OVERWRITTEN each chat (current snapshot)
create table memory_state (
  child_id             uuid primary key references children(child_id) on delete cascade,
  level                text not null default 'A1'
                         check (level in ('A1','A2','B1','B2','C1','C2')),
  progression_model    text not null default 'units'         -- ADDED: engine needs current mode
                         check (progression_model in ('micro-skill','units')),
  active_unit          text,
  owned                jsonb not null default '[]'::jsonb,
  emerging             jsonb not null default '[]'::jsonb,
  due_next             jsonb not null default '{"primary":null,"watching":[]}'::jsonb,
  last_topics          jsonb not null default '[]'::jsonb,    -- ring buffer, max 5
  sightings            jsonb not null default '{}'::jsonb,    -- per-skill qualifying counts
  strength             jsonb not null default '{}'::jsonb,    -- unprompted demonstrations
  last_seen            jsonb not null default '{}'::jsonb,    -- per-skill date (decay, later)
  effort_times_spoken  int  not null default 0,               -- lifetime number
  chat_count           int  not null default 0,
  updated_after_chat   int  not null default 0,
  updated_at           timestamptz default now()
);

-- 6. TRANSCRIPTS: one row per chat, stored apart so logs stay lean
create table transcripts (
  transcript_id  uuid primary key default gen_random_uuid(),
  child_id       uuid references children(child_id) on delete cascade,
  turns          jsonb not null default '[]'::jsonb,  -- [{speaker, text, stt_confidence}]
  created_at     timestamptz default now()
);

-- 7. SESSION LOGS: one row per chat, IMMUTABLE, accumulates (evidence trail)
create table session_logs (
  session_id         uuid primary key default gen_random_uuid(),
  child_id           uuid references children(child_id) on delete cascade,
  chat_number        int,                                  -- sequential per child (history label)
  level              text not null check (level in ('A1','A2','B1','B2','C1','C2')),
  progression_model  text not null check (progression_model in ('micro-skill','units')),
  prompt_version     text,
  topic              text,
  turns_total        int default 0,
  aimed_at           jsonb default '[]'::jsonb,   -- due_next targets
  hit_targets        jsonb default '[]'::jsonb,   -- which actually showed up
  skills_evidenced   jsonb default '[]'::jsonb,   -- judge output (id, confidence, prompted, evidence)
  state_changes      jsonb default '[]'::jsonb,   -- what changed (id, from, to)
  transcript_ref     uuid references transcripts(transcript_id) on delete set null,
  created_at         timestamptz default now()
);

-- 8. ZOE EVALS: QA only, SAMPLED, drives nothing
create table zoe_evals (
  eval_id        uuid primary key default gen_random_uuid(),
  session_id     uuid references session_logs(session_id) on delete cascade,
  level          text,
  rubric_scores  jsonb default '{}'::jsonb,
  judge_model    text,
  created_at     timestamptz default now()
);

-- ---------- indexes for common lookups ----------
create index idx_session_logs_child  on session_logs(child_id, created_at desc);
create unique index uq_session_child_num on session_logs(child_id, chat_number);
create index idx_transcripts_child   on transcripts(child_id, created_at desc);
create index idx_children_auth       on children(auth_user_id);
create index idx_skills_level_strand on skill_catalogue(level, strand);
create index idx_topics_level        on topics_catalogue(level) where is_active;
```

**Later, when scaling 🔵:** `schools`, `teachers`, `classes` — nullable links from `children`.

---

# PART D — ROW-LEVEL SECURITY (finalized, hardened)

The critical fix from review: **clients get READ-ONLY on state tables; the engine (service role) does all writes and bypasses RLS automatically.**

```sql
-- ============================================================
-- Row-Level Security (FINAL)
-- ============================================================
alter table children        enable row level security;
alter table memory_state    enable row level security;
alter table transcripts     enable row level security;
alter table session_logs    enable row level security;
alter table zoe_evals       enable row level security;
alter table skill_catalogue enable row level security;
alter table topics_catalogue enable row level security;
alter table app_prompts     enable row level security;

-- ---- children: read own profile; update own profile but NOT ownership ----
create policy "read own profile" on children
  for select using (auth.uid() = auth_user_id);
create policy "update own profile" on children
  for update using (auth.uid() = auth_user_id)
  with check (auth.uid() = auth_user_id);   -- with check stops repointing auth_user_id

-- ---- state tables: CLIENT READ-ONLY (engine writes via service role) ----
create policy "read own memory" on memory_state
  for select using (child_id in (select child_id from children where auth_user_id = auth.uid()));

create policy "read own transcripts" on transcripts
  for select using (child_id in (select child_id from children where auth_user_id = auth.uid()));

create policy "read own sessions" on session_logs
  for select using (child_id in (select child_id from children where auth_user_id = auth.uid()));

-- ---- reference tables: any authenticated user may read ----
create policy "catalogue readable" on skill_catalogue
  for select to authenticated using (true);
create policy "topics readable" on topics_catalogue
  for select to authenticated using (true);
create policy "prompts readable" on app_prompts
  for select to authenticated using (true);
-- prompt WRITES: admin-only, via service role or a dedicated admin tool — no client write policy.

-- ---- zoe_evals: NO client policy = deny all clients. Engine service role still works. ----
```

**Why no write policies appear:** the engine connects with the Supabase **service role key**, which ignores RLS entirely. So it writes `memory_state`, `session_logs`, `transcripts`, `zoe_evals` freely — while the policies above guarantee a child's app can only *read* its own rows and can never forge state. That is exactly the Part-0 principle enforced at the database layer.

---

# PART E — THE DETERMINISTIC ENGINE (the rules that must never drift)

These constants and rules are the actual definition of progress. They live in version-controlled engine code **with unit tests**, identical in the engine and in any Flutter mirror.

## E.1 Constants ✅

| Constant | Value | Meaning |
|---|---|---|
| `FLOOR` | 0.3 | Below this confidence, evidence is ignored entirely. |
| `OWN_BAR` | A1 0.55 · A2 0.60 · B1 0.68 · B2 0.72 · C1 0.75 · C2 0.78 | Confidence for a "qualifying sighting." Rises with level: beginners own by being understood, advanced learners by being accurate. |
| `SIGHTINGS_TO_OWN` | 2 | Qualifying sightings needed (across different chats) to own a skill. |

## E.2 Promotion rule (`applyMerge`) ✅

For each judged skill, given its confidence `c`:
- Record `last_seen` if `c ≥ FLOOR`.
- If `c ≥ OWN_BAR[level]` → increment `sightings`.
- If the skill was used spontaneously (`prompted = false`) → increment `strength`.
- **Effort path (A1/A2 only):** `strength + sightings ≥ 3` and `c ≥ FLOOR`.
- State transition:
  - `c < FLOOR` → no change.
  - `locked` → `emerging` (any evidence at/above floor).
  - `emerging` → `owned` if `sightings ≥ 2` **or** effort path.
- No demotion (decay deferred 🔵).

## E.3 Targeting (`due_next`) ✅

**Skill mode:** pick (1) the first emerging skill at this level → (2) the first locked skill in the *weakest strand* (fewest owned) → (3) a familiar owned skill. One primary + a small watch-list.

**Unit mode:** within the active step, target unowned skills ordered **FLU → VOC → GRA** (communicative core first, grammar matures last).

## E.4 Unit completion gate ✅

A unit step is complete when its **FLU and VOC skills are owned AND its GRA skills are at least emerging** (not locked). All steps complete → level-up.

## E.5 Topic selection (`pickTopic`) ✅

Level-appropriate topic, excluding the last 5 in `last_topics`, lightly matched to `interests`. Falls back to random within level if all recently used.

---

# PART F — CURRICULUM SEED DATA ✅ (with a correction)

| Set | Count | Notes |
|---|---|---|
| Flat CEFR skills | **124** | **Not 126.** A1 and A2 have only **6** FLU skills each (not 7). Per level: A1 20, A2 20, B1 21, B2 21, C1 21, C2 21. |
| Unit skills | 19 | 5 steps: 3 / 4 / 4 / 4 / 4. |
| Topics | per level | ~11–12 each across all 6 levels (the `TOPICS` object). |
| Prompt keys | 6 | base, profileA1, profileB1, convSkill, convUnit, judge. |

⚠️ **Seed verification:** the earlier reference doc said 126 ("7×3×6"). The actual simulator `CAT` array has **124** because A1-FLU and A2-FLU stop at `-06`. Seed from the real array, not the formula, and add a row-count assertion to your seed script.

---

# PART G — OPEN DECISIONS (confirm before building) 🟡

These are the genuine forks. Each changes the schema or RLS, so decide now.

**D1 — Who is the auth user?** *(highest priority — it validates the whole RLS design)*
The current schema assumes **the child is the auth user** (`children.auth_user_id → auth.users`). This works only if learners are old enough to hold their own login. The C1/C2 topics (AI ethics, democracy, caste) suggest teenagers, which makes this fine. **But if any learners are young children**, you need a parent/teacher-owns-child model instead, and every RLS policy changes. Confirm the youngest learner age.

**D2 — Editable prompts: keep `app_prompts` or not?**
Included above as optional. Keep it if you want to tune Zoe without an app/engine deploy (the simulator had a full editor for this). Drop it if prompts-as-code with deploys is acceptable. Decide; don't leave it ambiguous.

**D3 — Memory history: snapshots or replay?**
Current design has none — you reconstruct past state by replaying `session_logs`. Cheaper writes, but "show the garden as it was at chat 12" means replaying every merge. If progression charts are a core teacher feature, add a `memory_snapshots` table (one JSONB row per chat). If not, skip it.

**D4 — Dual-judge in production?**
The second (Zoe/units-vs-skill) judge doubles judge cost. It's a design/QA tool, not learner-facing. Recommend: **sample it** (e.g. 1 in N chats) rather than run every chat. `zoe_evals` already supports this.

**D5 — Audio retention.**
On-device STT means audio needn't leave the phone. If you keep any audio (for QA/appeals), define the Storage bucket, retention window, and deletion policy now — it's minors' voice data.

---

# PART H — WHAT YOU MIGHT BE MISSING (checklist) ✅

Things not in either doc that a production build needs:

- [ ] **Engine unit tests** for every E-section rule (the merge is where correctness lives — test it like a payments system).
- [ ] **Seed scripts** for `skill_catalogue`, `topics_catalogue`, `app_prompts`, with a **row-count assertion** (expect 124 + 19 skills).
- [ ] **`updated_at` triggers** on `memory_state` (and anywhere you rely on it).
- [ ] **Service-role key handling** — engine env only, never in the app, never in client config.
- [ ] **Data-deletion path** (DPDP / child-data right-to-erasure): a function that hard-deletes a child and cascades. The `on delete cascade` FKs already support this; wrap it in an audited endpoint.
- [ ] **Realtime subscription** on `memory_state` for live dashboards (optional but cheap).
- [ ] **Rate/cost guardrails** on the LLM proxy (per-child daily cap) so a stuck loop can't run up a bill.
- [ ] **Level-up / unit-complete events** surfaced to the child as celebrations and logged for analytics.
- [ ] **STT confidence handling** — `transcripts.turns` stores `stt_confidence`; decide what the engine does with a low-confidence turn (e.g. Zoe asks the child to repeat — there's a skill for that: A1-FLU-04).
- [ ] **Prompt versioning discipline** — bump `app_prompts.version` and stamp it on `session_logs.prompt_version` so score changes can be correlated to prompt changes.

---

## Summary of changes made to your colleague's original

Kept his architecture wholesale (on-device voice, engine-as-service, lean transcripts, overwrite-vs-accumulate, `zoe_evals` QA-only). Added on top:

1. **RLS hardened** — clients read-only on state tables; `with check` on profile; `to authenticated` on catalogue; engine writes via service role.
2. **CHECK constraints** on all enums (level, strand, progression_model, kind).
3. **`progression_model` added to `memory_state`** — the engine needs the current mode at chat start.
4. **`topics_catalogue` added** — topics had no home in the original.
5. **`app_prompts` added (optional)** — for prompt edits without a deploy.
6. **`chat_number` + unique index** — restores the simulator's "chat #N" history label.
7. **Curriculum count corrected** — 124 flat skills, not 126.
8. **Open decisions + missing-pieces checklist** — so nothing ships by accident.
