# ELLA App — Supabase → Ella REST API Migration

**Branch:** `feature/ella-simulator-garden-ui`
**Status:** Working tree (uncommitted) on top of commit `09ea087` ("rules for due_next stage")
**Scope:** The Flutter app (`ella_app/`) now runs entirely on the **Ella REST API**
(`https://ella.navgurukul.org/api`) for auth, memory, sessions, conversation, and
scoring. Supabase is no longer on the chat path.

---

## 1. Architecture: before vs after

| Concern | Before (Supabase + local engine) | After (Ella API) |
|---|---|---|
| Auth | Supabase anonymous auth | `POST /auth/anonymous` (bearer token cached in `SharedPreferences`) |
| Child memory (owned/emerging/due_next) | Local Dart engine wrote to Supabase | `GET /users/me/memory` (server owns the merge) |
| Level / placement | Supabase row | `GET /placements/latest` |
| Session list / history | Supabase tables | `GET /session` |
| Start a session | local | `POST /session` (returns `session_id`, `starter`, `aimed_at`) |
| Zoe's replies | local LLM (`llm.conv`) | `POST /session/{id}/turn` |
| End-of-chat scoring + merge | local `applyMerge` / `applyEndChat` + Supabase write | `POST /llm/session-analysis` (+ `/llm/judge`) |
| due_next **stage** | local engine | **local engine, recomputed over server memory** (see §5) |

**Design principle preserved:** the LLM only *talks* and *scores*; deterministic
code decides state. The deterministic merge now runs server-side; the local
`core/engine.dart` remains the authority for the **due_next stage** and is also
the offline fallback.

---

## 2. ⚠️ Backend topology — important

The Flutter client targets the **deployed "Ella API"** at `ella.navgurukul.org`.
**That server's source is NOT in this repo.** The repo's `backend/` folder is a
different, older service titled **"Zoe API"** with different routes
(`/conversations`, `/llm/conversation-turn`) and a different analysis schema. Do
**not** edit `backend/` expecting it to change the running app.

Consequences (things the frontend cannot control without a deployed-backend change):
- **What Zoe practices mid-conversation** — `aimed_at` is chosen by the server in
  `POST /session` and `/turn`; those endpoints accept no target list.
- **owned/emerging promotion** — computed server-side in `session-analysis`.
- **Live conversation progression-model framing** — `POST /session` / `/turn` accept
  no `progression_model`. Only `session-analysis` / `judge` accept it.

---

## 3. API integration map

All calls go through `lib/services/ella_api_service.dart` (`EllaApiService`),
provided by `ellaApiServiceProvider`. Wiring lives in
`lib/providers/chat_provider.dart`.

| Endpoint | Service method | Where wired |
|---|---|---|
| `POST /auth/anonymous` | `getOrCreateToken` | `build()` — startup auth |
| `GET /users/me/memory` | `getUserMemory` | `build()` (resume) · `endChat()` (merged state) |
| `GET /placements/latest` | `latestPlacement` | `build()` — level override |
| `GET /session` | `listSessions` | `build()` — restore Session/History tabs |
| `POST /session` | `createConversation` | `startSession()` — new session + `aimed_at` |
| `POST /llm/conversation-starter` | `conversationStarter` | `startSession()` — starter fallback |
| `POST /session/{id}/turn` | `conversationTurn` | `_zoeTurn()` — Zoe's reply |
| `POST /llm/session-analysis` | `sessionAnalysis` | `endChat()` — primary scoring/merge |
| `POST /llm/judge` | `judge` | `endChat()` — secondary judge pass |

**Built but not yet wired into the flow:** `updatePersonaMemory`
(`PUT /users/me/memory`), `getConversation`, `getMessages`/`storeMessage`,
`listPlacements`/`createPlacement`, `progressSummary`.

---

## 4. Progression-model fix (units vs micro-skill)

**Symptom:** the app always behaved as `micro-skill`, even after the mode pill was
hidden / defaulted to `units`.

**Root cause:** the server's `session-analysis` schema keys off `progression_model:
"unit"` (singular, its default). The client was sending `"units"` (plural), which
the server read as *not* units → micro-skill framing.

**Fix** (`ella_api_service.dart`): added `_serverProgressionModel()` mapping the
app tokens to the server's vocabulary, applied in `sessionAnalysis` + `judge`:

```
units       -> unit
micro-skill -> micro_skill
```

**Mode pill hidden:** the toggle is cosmetic while the live conversation framing is
server-controlled, so it's hidden behind `kShowModePill = false` in
`child_chat_screen.dart` (flip to `true` to restore).

**Judge framing:** the end-chat `judge` call previously used the *opposite* framing
(for the simulator's dual-judge comparison), which is why logs showed `micro_skill`
while in units mode. It now uses the **same** `mode` as the primary analysis, so
both `session-analysis` and `judge` send the same token. (`otherMode` removed.)

> Still TODO on the deployed backend: add `progression_model` to `CreateConversationRequest`
> and use it when building the session, so the **live conversation** honors units too.

---

## 5. due_next stage driven by the frontend engine

**Symptom:** the rule changes from commit `09ea087` (in `core/engine.dart`:
`dueUnit`, `unitComplete`, emerging-cleanup) had no visible effect when testing
online.

**Root cause:** online, the app used the **server's** `due_next` and discarded the
locally-computed one.

**Fix** (`chat_provider.dart`): after fetching server memory, recompute `due_next`
locally with `targetsListFor(...)` so the engine rules are authoritative for the
**due_next stage** (display + judge framing). Server still owns owned/emerging.

- `build()` — after the placement-level adjustment:
  `mem = mem.copyWith(dueNext: targetsListFor(mem, mem.progressionModel, mem.level));`
- `endChat()` — after the post-chat memory re-fetch, recompute on the server memory
  before storing it in state.

Engine rules now in effect online:
1. No active unit but unit skills still emerging → `dueUnit()` returns the emerging
   cleanup picks instead of empty.
2. 3+ emerging unit skills → cleanup is prioritized before opening new active-unit work.
3. Next unit unlocks when owned ≥ 50% of the unit's skills.

> These affect the **due_next tab / garden** and **judge framing** only. Zoe's live
> targeting (`aimed_at`) remains server-side.

---

## 6. Diagnostics: full API logging

`EllaApiService._request()` logs every request, response, and network error via
`debugPrint` (visible in the `flutter run` console, Android logcat, and the web
browser console). Debug builds only (`kDebugMode`), pretty-printed JSON, boxed and
tagged `[EllaAPI]`:

```
┌─[EllaAPI] REQUEST  POST .../llm/session-analysis
│ { "progression_model": "unit", ... }
└────────────────────────────────────────
┌─[EllaAPI] RESPONSE POST /llm/session-analysis  HTTP 200
│ { "skills_evidenced": [...], "state_changes": [...] }
└────────────────────────────────────────
```

**View:** Android — `flutter logs` / `adb logcat` (filter `EllaAPI`); Web —
DevTools → Console.

---

## 7. Web platform enabled

`flutter create --platforms=web .` added `ella_app/web/`. Run with
`flutter run -d chrome`. Caveats:
- **CORS** — browser calls to `ella.navgurukul.org` require the server to send
  `Access-Control-Allow-Origin`, or they'll be blocked (mobile is unaffected).
- **STT/TTS** — the native speech plugins may be no-ops on web; the typed-text chat
  path works regardless.

---

## 8. File-by-file change summary

| File | Change |
|---|---|
| `lib/services/ella_api_service.dart` | **New.** Full Ella API client + `_serverProgressionModel()` mapper + `_request()` logging. |
| `lib/providers/service_providers.dart` | Added `ellaApiServiceProvider` (base URL from `ELLA_API_BASE_URL`, defaults to prod). |
| `lib/providers/chat_provider.dart` | Online flow on the Ella API; local engine kept as offline fallback; `units→unit` via service; judge uses primary `mode`; **due_next recomputed locally** in `build()` + `endChat()`. |
| `lib/main.dart` | `Supabase.initialize` made best-effort (won't crash on missing env). |
| `lib/screens/child_view/child_chat_screen.dart` | Mode pill hidden behind `kShowModePill = false`. |
| `pubspec.yaml` | Added `shared_preferences` (token cache). |
| `web/` | New web platform. |

---

## 9. Residual Supabase (intentional — not on chat path)

- `main.dart` — best-effort `Supabase.initialize` (only if env present).
- `service_providers.dart` — `supabaseServiceProvider` registered but no longer read
  by `chat_provider`.
- `services/supabase_service.dart` — class exists, unused in the flow.
- `screens/glass_box/tabs/llm_info_tab.dart` — Glass Box (testing) tab reads the
  Supabase auth uid.

Can be fully removed if/when the Glass Box no longer needs Supabase.

---

## 10. Offline / fallback behavior

When startup auth or memory load fails, `_online = false` and the app runs locally:
- Zoe replies via local `llm.conv` (LLM proxy).
- End-chat scoring via local `applyMerge` / `applyEndChat`.
- `mockLearner` (auto-mode "fake child") is a test feature, not real product use.

---

## 11. Verify / run

```bash
cd ella_app
flutter analyze lib            # expect: No issues found
flutter test test/core/engine_test.dart   # engine + due_next rules
flutter run                    # Android/iOS; watch [EllaAPI] logs
flutter run -d chrome          # web (mind CORS)
```

**Confirm the fixes via logs:** end a chat online and check the
`REQUEST POST /llm/session-analysis` body shows `"progression_model": "unit"`, and
the `GET /users/me/memory` response's `due_next` reflects the engine rules.

---

## 12. Outstanding (needs the deployed Ella API repo — not in this monorepo)

1. Add `progression_model` to `CreateConversationRequest` so the **live conversation**
   honors units (currently only end-chat scoring does).
2. If Zoe's live targeting should follow the new due_next rules, port the
   `core/engine.dart` due_next logic (rules 1–3 above) into the server.
3. Confirm the server's exact progression-model tokens (`unit` / `micro_skill`); adjust
   `_serverProgressionModel()` if they differ.
