-- ============================================================
-- ELLA — Row-Level Security
-- Source: ELLA-Final-Build-Spec.md Part D
--
-- D1 ASSUMPTION: child is the auth user (children.auth_user_id → auth.users).
-- This works for learners old enough to hold a login (pre-teens and up).
-- If you later need parent/teacher-owns-child, every policy below must be
-- rewritten to check a guardian join — do that before launch for young children.
--
-- TESTING-PHASE OVERRIDE
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │  Section A (below) enables INSERT/UPDATE on state tables with the anon  │
-- │  key so the Flutter app can write state directly during development.     │
-- │  Section B shows the PRODUCTION-CORRECT version to switch to later:     │
-- │  delete Section A policies and set writes to service-role only.         │
-- └─────────────────────────────────────────────────────────────────────────┘
-- ============================================================

-- ── Enable RLS on all tables ─────────────────────────────────────────────────
alter table children         enable row level security;
alter table memory_state     enable row level security;
alter table transcripts      enable row level security;
alter table session_logs     enable row level security;
alter table zoe_evals        enable row level security;
alter table skill_catalogue  enable row level security;
alter table topics_catalogue enable row level security;
alter table app_prompts      enable row level security;

-- ── children: read + update own profile ────────────────────────────────────
create policy "read own profile" on children
  for select using (auth.uid() = auth_user_id);

create policy "update own profile" on children
  for update using (auth.uid() = auth_user_id)
  with check (auth.uid() = auth_user_id);

-- ── reference tables: any authenticated user may read ──────────────────────
create policy "catalogue readable" on skill_catalogue
  for select to authenticated using (true);

create policy "topics readable" on topics_catalogue
  for select to authenticated using (true);

create policy "prompts readable" on app_prompts
  for select to authenticated using (true);

-- ── State tables: read-only for clients ────────────────────────────────────
create policy "read own memory" on memory_state
  for select using (
    child_id in (select child_id from children where auth_user_id = auth.uid())
  );

create policy "read own transcripts" on transcripts
  for select using (
    child_id in (select child_id from children where auth_user_id = auth.uid())
  );

create policy "read own sessions" on session_logs
  for select using (
    child_id in (select child_id from children where auth_user_id = auth.uid())
  );

-- zoe_evals: NO client policy → deny all clients; service role still writes.


-- ════════════════════════════════════════════════════════════════════════════
-- SECTION A — TESTING-PHASE WRITE POLICIES (DELETE BEFORE PRODUCTION)
-- These allow the Flutter app to write state directly with the anon key.
-- They bypass the "engine writes via service role" production principle.
-- ════════════════════════════════════════════════════════════════════════════

create policy "_TEST_ upsert own memory" on memory_state
  for all using (
    child_id in (select child_id from children where auth_user_id = auth.uid())
  )
  with check (
    child_id in (select child_id from children where auth_user_id = auth.uid())
  );

create policy "_TEST_ insert own sessions" on session_logs
  for insert with check (
    child_id in (select child_id from children where auth_user_id = auth.uid())
  );

create policy "_TEST_ update own sessions" on session_logs
  for update using (
    child_id in (select child_id from children where auth_user_id = auth.uid())
  );

create policy "_TEST_ insert own transcripts" on transcripts
  for insert with check (
    child_id in (select child_id from children where auth_user_id = auth.uid())
  );

-- Also allow children to insert their own profile row (testing: no admin portal yet)
create policy "_TEST_ insert own child row" on children
  for insert with check (auth.uid() = auth_user_id);


-- ════════════════════════════════════════════════════════════════════════════
-- SECTION B — PRODUCTION-CORRECT VERSION (for reference — do NOT run now)
--
-- When you are ready for production:
-- 1. Drop all policies prefixed with "_TEST_".
-- 2. Remove Section A entirely.
-- 3. The engine Edge Function connects with the SERVICE ROLE KEY (set in
--    Supabase → Settings → API → service_role). Service role bypasses RLS
--    automatically — no write policies needed.
-- 4. App connects with ANON KEY only → gets SELECT on its own rows only.
--    It can never forge owned/emerging/due_next.
--
-- To drop the test policies when ready:
--   drop policy "_TEST_ upsert own memory"      on memory_state;
--   drop policy "_TEST_ insert own sessions"    on session_logs;
--   drop policy "_TEST_ update own sessions"    on session_logs;
--   drop policy "_TEST_ insert own transcripts" on transcripts;
--   drop policy "_TEST_ insert own child row"   on children;
-- ════════════════════════════════════════════════════════════════════════════
