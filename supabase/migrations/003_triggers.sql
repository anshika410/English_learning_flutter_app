-- ============================================================
-- ELLA — Triggers
-- updated_at auto-bump on memory_state (Part H checklist item).
-- ============================================================

create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_memory_state_updated_at
  before update on memory_state
  for each row execute function set_updated_at();

create trigger trg_app_prompts_updated_at
  before update on app_prompts
  for each row execute function set_updated_at();
