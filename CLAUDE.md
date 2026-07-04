# CLAUDE.md — ELLA Flutter App

> This file is auto-loaded by Claude Code. It tells you how to build the ELLA app
> inside this repo. Read it fully before writing any code.

## What we're building

A new Flutter app, **ELLA** — an AI spoken-English tutor for children. It is a port of
the working prototype in `docs/ella-loop-sim-2.html` (a self-contained HTML simulator).
The simulator's logic is the spec; reproduce its behaviour exactly.

The app has **two tabs**:
1. **Child View** — voice + text chat with "Zoe" + a garden that shows progress. The child can
   either speak (mic → on-device STT) or type (text field); both feed the same loop and Zoe
   always replies aloud via TTS. This is the real product.
2. **Glass Box** — the engine's internals (memory, judge scores, due_next, prompt, history).
   **Testing only.** It must sit behind a single flag `kShowGlassBox` so we can hide it for
   production by changing one line. Keep it for now.

Backend is **Supabase** (fresh integration — nothing is set up yet; you will create it all).

## Before you start — inspect the repo

This is a monorepo with an existing app. Before scaffolding, do this and report back:
1. List the repo structure (top 2 levels). Identify where the old app lives.
2. Find the **STT and TTS** implementation in the old app. Report the package(s) used
   (e.g. sherpa-onnx, speech_to_text, flutter_tts) and the files. We will reuse this.
3. Identify the old app's **state management** (Riverpod / Bloc / Provider / setState) and
   **Flutter/Dart SDK versions**. Match the new app to these conventions.
4. Confirm whether the repo uses a workspace tool (melos, etc.) or plain folders.
5. Then propose exactly where the new `ella_app/` folder goes and wait for confirmation.

Do not modify the old app. Only reuse its STT/TTS by extracting an interface.

## The non-negotiable principle

**LLMs only talk (Zoe) and score (judge). Plain Dart/engine code makes every decision
about a child's state.** No LLM ever writes `owned`, `emerging`, or `due_next`.

For the **testing phase**, the deterministic engine runs as **pure Dart inside the app**,
and the app writes state directly to Supabase. (Later we move the engine to a Supabase
Edge Function and make the app read-only — see docs/ELLA-Final-Build-Spec.md Part G/D1.
Build it now so that swap is easy: keep all engine logic in `core/engine.dart` with no
Flutter or network imports.)

## Source-of-truth documents (read these)

- `docs/ELLA-Final-Build-Spec.md` — schema, RLS, engine rules, constants. Authoritative.
- `docs/ella-loop-sim-2.html` — the behaviour to reproduce. The `CAT`, `UNITS_A1`,
  `TOPICS`, `DEFAULT_PROMPTS` arrays and the engine functions (`applyMerge`, `dueSkill`,
  `dueUnit`, `unitComplete`, `pickTopic`, `buildConvPrompt`, `runJudge`, `endChat`) are
  the spec for `core/`.

## Engine constants (must match exactly — put in core/constants.dart)

- `FLOOR = 0.3`
- `OWN_BAR = {A1:0.55, A2:0.60, B1:0.68, B2:0.72, C1:0.75, C2:0.78}`
- `SIGHTINGS_TO_OWN = 2`
- Effort path (A1/A2 only): `strength + sightings >= 3 && confidence >= FLOOR` also promotes.
- Unit complete: FLU+VOC owned AND GRA at least emerging.
- Curriculum is **124 flat skills** (A1/A2 have 6 FLU each, not 7) + **19 unit skills**.
  Verify counts against the simulator's `CAT`/`UNITS_A1` when seeding — assert the totals.

## Target folder layout for the new app

```
ella_app/
  lib/
    core/        constants.dart engine.dart skill_data.dart topic_data.dart prompts.dart
    models/      child_memory.dart session.dart message.dart skill.dart score.dart
    services/    supabase_service.dart llm_service.dart stt_tts_service.dart
    providers/   chat_provider.dart memory_provider.dart session_provider.dart
    screens/
      child_view/   child_chat_screen.dart garden.dart chat_bubble.dart
      glass_box/    glass_box_screen.dart  tabs/*.dart
    app.dart      // TabBar: [Child View | Glass Box], kShowGlassBox flag
    main.dart     // Supabase.initialize + run
  pubspec.yaml
supabase/
  migrations/   // schema.sql + rls.sql from the spec
  functions/llm-proxy/   // Edge Function (keys server-side)
  seed/         // skill_catalogue, topics_catalogue, app_prompts seed scripts
```

## Rules while coding

- `core/` is pure Dart — no Flutter, no network, no Supabase imports. It must be unit-testable.
- Write a unit test for every engine rule before wiring UI (the merge is where correctness lives).
- Never put API keys in the app. Keys live only in the `llm-proxy` Edge Function env.
- Use the old app's STT/TTS via an extracted `SttTtsService` interface — don't duplicate it.
- Reproduce simulator behaviour first; do not "improve" the pedagogy or scoring.
- Match the old app's state-management choice. If it's setState only, use Riverpod for the
  new app but say so explicitly.

## Build order (one phase per session — wait for review between phases)

1. Inspect repo + confirm folder placement + STT/TTS findings.
2. Scaffold `ella_app/` + `core/` (constants, engine, skill_data, topic_data, prompts) + tests.
3. Models + `supabase_service` + `llm_service` (proxy client) + `stt_tts_service` (port).
4. Supabase: schema.sql, rls.sql, seed scripts, `llm-proxy` function. Give exact CLI steps.
5. Child View (chat + garden + mic) wired to providers.
6. Glass Box tabs behind `kShowGlassBox`.
7. End-to-end test against the simulator's behaviour.
