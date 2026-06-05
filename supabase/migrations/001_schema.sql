-- ============================================================
-- ELLA — Supabase schema (FINAL)
-- Source: ELLA-Final-Build-Spec.md Part C
-- Run top-to-bottom. Postgres / Supabase.
-- ============================================================

create extension if not exists "pgcrypto";

-- 1. STATIC REFERENCE: skill catalogue (flat CEFR + unit skills)
create table skill_catalogue (
  skill_id        text primary key,
  level           text check (level in ('A1','A2','B1','B2','C1','C2')),
  strand          text not null check (strand in ('VOC','GRA','FLU')),
  statement_text  text not null,
  object          text,               -- garden plant shown to the child
  kind            text not null default 'flat' check (kind in ('flat','unit')),
  unit_step       text,               -- '1'..'5' for unit skills
  unit_name       text,
  unit_focus      text,
  created_at      timestamptz default now()
);

-- 2. STATIC REFERENCE: topic bank
create table topics_catalogue (
  topic_id   uuid primary key default gen_random_uuid(),
  level      text not null check (level in ('A1','A2','B1','B2','C1','C2')),
  theme      text not null,
  topic      text not null,
  starters   text,
  is_active  boolean not null default true,
  created_at timestamptz default now()
);

-- 3. EDITABLE AI CONFIG (keep: enables prompt tuning without a deploy)
create table app_prompts (
  key        text primary key
               check (key in ('base','profileA1','profileB1','convSkill','convUnit','judge')),
  content    text not null,
  version    int not null default 1,
  updated_at timestamptz default now()
);

-- 4. CHILDREN: one row per learner
create table children (
  child_id       uuid primary key default gen_random_uuid(),
  auth_user_id   uuid references auth.users(id) on delete cascade,
  name           text,
  age            int check (age between 3 and 19),
  grade          text,
  home_language  text default 'Hindi',
  interests      text,
  created_at     timestamptz default now()
);

-- 5. MEMORY STATE: one row per child, OVERWRITTEN each chat
create table memory_state (
  child_id             uuid primary key references children(child_id) on delete cascade,
  level                text not null default 'A1'
                         check (level in ('A1','A2','B1','B2','C1','C2')),
  progression_model    text not null default 'units'
                         check (progression_model in ('micro-skill','units')),
  active_unit          text,
  owned                jsonb not null default '[]'::jsonb,
  emerging             jsonb not null default '[]'::jsonb,
  due_next             jsonb not null default '{"primary":null,"watching":[]}'::jsonb,
  last_topics          jsonb not null default '[]'::jsonb,
  sightings            jsonb not null default '{}'::jsonb,
  strength             jsonb not null default '{}'::jsonb,
  last_seen            jsonb not null default '{}'::jsonb,
  effort_times_spoken  int  not null default 0,
  chat_count           int  not null default 0,
  updated_after_chat   int  not null default 0,
  updated_at           timestamptz default now()
);

-- 6. TRANSCRIPTS: full turn-by-turn log
create table transcripts (
  transcript_id  uuid primary key default gen_random_uuid(),
  child_id       uuid references children(child_id) on delete cascade,
  turns          jsonb not null default '[]'::jsonb,
  created_at     timestamptz default now()
);

-- 7. SESSION LOGS: one row per chat, IMMUTABLE evidence trail
create table session_logs (
  session_id         uuid primary key default gen_random_uuid(),
  child_id           uuid references children(child_id) on delete cascade,
  chat_number        int,
  level              text not null check (level in ('A1','A2','B1','B2','C1','C2')),
  progression_model  text not null check (progression_model in ('micro-skill','units')),
  prompt_version     text,
  topic              text,
  turns_total        int default 0,
  aimed_at           jsonb default '[]'::jsonb,
  hit_targets        jsonb default '[]'::jsonb,
  skills_evidenced   jsonb default '[]'::jsonb,
  state_changes      jsonb default '[]'::jsonb,
  transcript_ref     uuid references transcripts(transcript_id) on delete set null,
  created_at         timestamptz default now()
);

-- 8. ZOE EVALS: QA only, sampled, drives nothing
create table zoe_evals (
  eval_id        uuid primary key default gen_random_uuid(),
  session_id     uuid references session_logs(session_id) on delete cascade,
  level          text,
  rubric_scores  jsonb default '{}'::jsonb,
  judge_model    text,
  created_at     timestamptz default now()
);

-- ── Indexes ─────────────────────────────────────────────────────────────────
create index idx_session_logs_child  on session_logs(child_id, created_at desc);
create unique index uq_session_child_num on session_logs(child_id, chat_number);
create index idx_transcripts_child   on transcripts(child_id, created_at desc);
create index idx_children_auth       on children(auth_user_id);
create index idx_skills_level_strand on skill_catalogue(level, strand);
create index idx_topics_level        on topics_catalogue(level) where is_active;
