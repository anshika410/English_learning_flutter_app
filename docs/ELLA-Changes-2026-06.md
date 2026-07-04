# ELLA Flutter App — June 2026 changes

A single-document log of everything that changed in the `ella_app/` Flutter app and
`supabase/` directory across this work session. Read top-to-bottom for the story;
skim section headings for what changed where.

Date range: 2026-06-04 → 2026-06-05
Branch: `feature/ella-simulator`
Scope: app + Supabase shape only. The pure-Dart engine in `ella_app/lib/core/`
and the LLM proxy edge function are untouched.

---

## TL;DR

1. **Simulator parity** — the Flutter Child View + Glass Box now look and behave
   like `docs/ella-loop-sim-2.html`: mode toggle, level selector, status line,
   auto mode, dual judging, all the Glass Box tabs (Memory, Judge, Both, Session,
   Due Next, Prompt, Edit Prompts, Skills/Units, History, ReadMe, LLM info).
2. **Reliability fixes** — mic now auto-submits on the 4 s silence pause;
   End Chat no longer crashes when one judge call fails; Next Chat always works;
   removed the garden bar from the chat screen; Memory tab now shows the memory
   object as a single formatted JSON block (matches the simulator).
3. **Supabase persistence** — the app actually writes to `children`,
   `memory_state`, `session_logs`, `transcripts` now. Required: enable
   **Anonymous Sign-Ins** in the Supabase project (see setup steps below).
4. **Offline mode** — if anon sign-in is disabled or unreachable, the app falls
   back to in-memory-only and shows a red sync-error banner in the Memory tab
   instead of crashing.
5. **Permissions** — removed Bluetooth permissions; the app now only asks for
   Microphone (and uses Internet implicitly).
6. **APK** — `flutter build apk --release` from `ella_app/` produces a 51 MB
   release APK at
   `ella_app/build/app/outputs/flutter-apk/app-release.apk`.

Final test run: `dart analyze lib/` → 0 issues; `flutter test` → 99/99 pass.

---

## 1. Simulator parity rebuild

The Flutter app was missing most of the simulator's controls and Glass Box tabs.
Closed the gap as follows:

### Child View (`lib/screens/child_view/child_chat_screen.dart`)

- Mode-toggle pill in the AppBar: `micro-skill ⟷ units`.
- Status line under the AppBar:
  `Chat #N · mode · level · turns: X · lifetime: Y · LLM: live/mock`.
- Voice / Text input dock with mic-tap-toggle and live STT partial preview.
- Bottom control row: `🤖 auto` / `✋ manual`, `End chat ⚖️`, `Next chat →`,
  `Reset` (with confirm dialog).
- When `autoMode == true`: only the "Next turn ▶" button is shown.
- After `endChat`: "Start a new chat" pill replaces the input dock.

### Glass Box (`lib/screens/glass_box/glass_box_screen.dart`)

- Level dropdown (A1 … C2) in the top bar. Switching wipes in-memory state and
  starts a fresh chat at the new level.
- 11 tabs in a scrollable TabBar:
  1. 📖 **Read me** — port of the simulator's ReadmeView.
  2. 🧠 **Memory** — JSON dump + sync-error banner + per-chat snapshots.
  3. ⚖️ **Judge** — raw scores from the last chat with evidence quotes.
  4. ⚖️⚖️ **Both** — side-by-side dual judging (primary vs. alternate framing).
  5. 📜 **Session** — accordion of immutable per-chat session records
     (now including the in-memory transcript).
  6. 🎯 **due_next** — current targeting picks and the "why" strings.
  7. 📝 **Prompt** — live-assembled Zoe and Judge prompts.
  8. ✏️ **Edit Prompts** — editable text areas for all 5 prompt templates.
  9. 🌱 **Skills** / 🪜 **Units** — switches by `progressionModel`.
  10. 📊 **History** — compact per-chat summaries (aimed/hit, turns, owned).
  11. ⚙️ **LLM** — static info panel explaining the Android app uses the
      Supabase proxy only.

### Provider (`lib/providers/chat_provider.dart`)

`ChatState` extended with all the new state the UI/Glass Box needs:

```
autoMode, autoStep, chatNumber, lastJudgeScores, lastJudgeScoresOther,
lastJudgeOtherLabel, snapshots, sessionLogs, historyEntries,
aimedAt, hitTargets, liveLlmLastCall, lastSyncError
```

New methods:

- `setProgressionModel(mode)`, `setLevel(level)`, `resetAll()`,
  `nextChat()`, `setAutoMode(bool)`, `autoTurn()`,
  `setPromptsOverride(AppPrompts)`.
- `endChat()` now runs **dual judging** in parallel (`primary` framing + `other`
  framing) so the Both tab can show side-by-side scores.

New providers:

- `lib/providers/prompts_provider.dart` — `StateProvider<AppPrompts>` so the
  Edit Prompts tab can mutate prompts live.

### New models

- `lib/models/memory_snapshot.dart`
- `lib/models/history_entry.dart`

Both are in-memory-only structures used by Glass Box; not persisted.

### New service method

- `LlmService.mockLearner(history, level)` — calls the same `/llm-proxy` with a
  role-play prompt to simulate a learner reply (powers auto mode).

---

## 2. Reliability fixes

### Mic stopped capturing without submitting

**Cause:** the speech_to_text plugin auto-stops after 4 s of silence
(`SpeechListenOptions(pauseFor: 4s)`), but only `onPartial` was wired. The final
result never triggered a submit.

**Fix (`lib/services/stt_tts_service.dart` + `chat_provider.dart`):** added an
`onFinal` callback. The plugin fires `result.finalResult: true` on auto-stop
*or* manual stop. `onFinal` flips status to idle and calls `sendUserTurn`.

### End Chat crashed when one judge call failed

**Cause:** `Future.wait([primary, other])` propagated *any* failure. The OTHER
framing judge often returned malformed JSON for skills with no evidence.

**Fix (`chat_provider.dart`):** each judge call now has its own
`.catchError((_) => <SkillScore>[])`. If the primary fails too, end-chat still
completes with `"⚠️ Judge unavailable — chat ended, no state changes."` as a
sys message, so the user can always hit **Next chat →**.

### Next Chat button did nothing

**Cause:** end-chat crashed → `sessionEnded` stayed `false` → the Next button
stayed disabled. Knock-on effect of the bug above. Also `_zoeTurn` was
rethrowing on conv-LLM failure, leaving the chat empty.

**Fix:** `_zoeTurn` falls back to a generic Zoe message
(`"Hmm, I'm having a moment. What were you saying?"`) on failure instead of
rethrowing. TTS failure is also swallowed (the message is already on screen).
Combined with the dual-judge fix above, Next Chat now always works.

### Garden bar removed

The simulator has no garden plant bar — just chat. Removed `Garden` and
`GrewBanner` from `child_chat_screen.dart`. The "Grew: X locked→emerging" sys
message in the chat covers state changes for now. `garden.dart` is kept on disk
in case we want to bring it back later.

### Memory tab now shows formatted JSON

Rewrote `lib/screens/glass_box/tabs/memory_tab.dart` to match the simulator's
MemoryView: a single dark monospace block built with
`JsonEncoder.withIndent('  ').convert(...)`, with the state-changes banner above
it and the per-chat snapshots list below.

---

## 3. Supabase persistence — the layered bug fix

**The symptom:** nothing was ever written to `children`, `memory_state`,
`session_logs`, or `transcripts`, even with the demo child UUID.

**Five layered root causes** (any one would have been enough to break writes):

### 3.1 RLS required auth

`supabase/migrations/002_rls.sql` — every `_TEST_` policy still requires
`auth.uid() = auth_user_id`. Without a logged-in user, `auth.uid()` is NULL and
every INSERT/UPDATE is rejected.

**Fix (`chat_provider.dart` build()):** call
`Supabase.instance.client.auth.signInAnonymously()` at startup. Use the anon
user's `auth.uid()` as the `child_id`.

**Required project setting:** Anonymous Sign-Ins must be enabled in the Supabase
dashboard. See "Setup checklist" below.

### 3.2 No `children` row

`kDemoChildId = '00000000-0000-0000-0000-000000000001'` was referenced only in
`chat_provider.dart` — nothing inserted it. Even with RLS passing, FK
constraints on `memory_state` / `session_logs` / `transcripts` would reject every
insert.

**Fix (`lib/services/supabase_service.dart`):** new
`ensureChild(childId, name?, homeLanguage?)` method — idempotent upsert keyed by
`child_id`, with `auth_user_id = child_id` so RLS passes. Called once at
startup after sign-in.

### 3.3 `SessionLog.toJson()` column mismatch

The old model sent `id`, `started_at`, `ended_at`, `turn_count`, `topic_used`.
The schema (`001_schema.sql:85-100`) has `session_id`, no started/ended columns,
`turns_total`, `topic`. Also `level` and `progression_model` are NOT NULL.

**Fix (`lib/models/session.dart`):** rewrote the whole class. New shape:

```dart
SessionLog({
  String? sessionId,         // schema PK (uuid)
  required String childId,
  required int chatNumber,
  required String level,         // NOT NULL in schema
  required String progressionModel, // NOT NULL in schema
  int turnsTotal = 0,
  String? topic,
  List<String> aimedAt,
  List<String> hitTargets,
  List<Map<String, dynamic>> judgeScoresRaw,  // → 'skills_evidenced'
  List<Map<String, dynamic>> stateChanges,
  String? transcriptRef,
  List<Map<String, dynamic>> transcript,  // IN-MEMORY ONLY (Session tab)
})
```

`toJson()` keys match column names exactly. `transcript` is **not** serialised
to Supabase — full transcripts live in the `transcripts` table.

### 3.4 `MemoryState.toJson()` extra `interests` key

The model included `interests`, which is a column on `children`, not
`memory_state`. Postgres rejected the upsert with "column does not exist".

**Fix (`lib/models/child_memory.dart`):** removed `interests` from
`toJson()`. The field stays in-memory and feeds the topic picker. If we want to
persist it later, that goes to `children`.

### 3.5 Silent error swallowing

The previous code wrapped Supabase calls in try-catch with no logging, so every
failure was invisible.

**Fix:** added `ChatState.lastSyncError` and a red banner at the top of the
Memory tab that shows the exact PostgrestException / AuthApiException whenever
a write or auth call fails. Cleared on the next successful endChat.

### Session tab transcript display

The Session tab JSON was missing the actual conversation turns (only the
`transcript_ref` UUID was visible). Added the in-memory `transcript` field to
`SessionLog` and merged it into the displayed JSON in
`lib/screens/glass_box/tabs/session_tab.dart`.

---

## 4. Offline mode

If anonymous sign-in is disabled in the Supabase project, or the device is
offline, anon sign-in throws
`AuthApiException(code: anonymous_provider_disabled)` or a network error. We
saw a follow-up bug where the fallback `_childId = "offline-<timestamp>"` was
not a valid UUID, so Postgres rejected the upsert with
`invalid input syntax for type uuid: 22P02`.

**Fix (`chat_provider.dart`):**

- Added `bool _online` flag on `ChatNotifier`. `true` only after successful
  `signInAnonymously` + `ensureChild`.
- Offline childId is now the nil UUID `00000000-0000-0000-0000-000000000000` so
  it satisfies Postgres `uuid` syntax (defensive — we don't write anyway).
- `endChat` wraps the entire Supabase persist block in `if (_online) { ... }`.
  No wasted requests, no PostgrestException spam.
- Offline mode sets a friendly banner:
  `"Offline mode — Supabase writes skipped (anon sign-in disabled?)."`

The UI works fully in memory in offline mode — only persistence is skipped.

---

## 5. Permissions cleanup

`ella_app/android/app/src/main/AndroidManifest.xml` previously declared:

- `android.permission.INTERNET` (kept — Supabase + LLM proxy)
- `android.permission.RECORD_AUDIO` (kept — STT)
- `android.permission.BLUETOOTH` ≤ SDK 30 (removed)
- `android.permission.BLUETOOTH_CONNECT` ≥ SDK 31 (removed)

The BLUETOOTH_CONNECT permission triggers Android 12's
"find / connect to / determine relative position of nearby devices" runtime
prompt. We don't need it — `speech_to_text` and `flutter_tts` work fine with
the device's built-in mic and speaker.

Reinstall the APK after this change to clear any previously granted Nearby
Devices permission.

---

## 6. APK build

Release APK is at:

```
ella_app/build/app/outputs/flutter-apk/app-release.apk   (~51 MB)
```

**Build command** — must be run from inside `ella_app/`, not the repo root
(the root also contains `frontend/`, which is a separate Flutter project):

```powershell
cd c:\Users\dhans\StudioProjects\ella_flutter\ella_app
flutter build apk --release
```

Other useful variants:

- `flutter build apk --debug` — bigger, faster build, easier to debug.
- `flutter build apk --split-per-abi` — three smaller APKs (armeabi-v7a,
  arm64-v8a, x86_64).
- `flutter build appbundle --release` — `.aab` for the Play Store.

The release APK is signed with the Flutter debug key by default. Fine for
sideloading; needs a proper keystore + `android/key.properties` before
publishing to the Play Store.

---

## 7. Files changed (this session)

```
ella_app/
├── android/app/src/main/AndroidManifest.xml         (- bluetooth permissions)
├── lib/
│   ├── core/prompts.dart                            (cleanup: unnecessary escapes)
│   ├── models/
│   │   ├── child_memory.dart                        (- interests from toJson)
│   │   ├── history_entry.dart                       (NEW)
│   │   ├── memory_snapshot.dart                     (NEW)
│   │   └── session.dart                             (rewrite: schema-shaped + transcript)
│   ├── providers/
│   │   ├── chat_provider.dart                       (major: anon auth, offline,
│   │   │                                             autoMode, dualJudge, snapshots,
│   │   │                                             sessionLogs, lastSyncError,
│   │   │                                             setLevel/setModel/nextChat/reset)
│   │   └── prompts_provider.dart                    (NEW)
│   ├── screens/
│   │   ├── child_view/
│   │   │   └── child_chat_screen.dart               (rewrite: mode toggle, status line,
│   │   │                                             controls, mic tap-toggle,
│   │   │                                             - garden, - GrewBanner)
│   │   └── glass_box/
│   │       ├── glass_box_screen.dart                (rewrite: level dropdown,
│   │       │                                         11 tabs)
│   │       └── tabs/
│   │           ├── dual_judge_tab.dart              (NEW)
│   │           ├── due_next_tab.dart                (kept)
│   │           ├── edit_prompts_tab.dart            (NEW)
│   │           ├── history_tab.dart                 (reformat)
│   │           ├── judge_tab.dart                   (NEW)
│   │           ├── llm_info_tab.dart                (NEW)
│   │           ├── memory_tab.dart                  (rewrite: JSON block, sync banner)
│   │           ├── prompt_tab.dart                  (kept)
│   │           ├── readme_tab.dart                  (NEW)
│   │           ├── session_tab.dart                 (include transcript in JSON)
│   │           └── skills_tab.dart                  (kept)
│   └── services/
│       ├── llm_service.dart                         (+ mockLearner)
│       ├── stt_tts_service.dart                     (+ onFinal callback)
│       └── supabase_service.dart                    (+ ensureChild)
└── test/
    └── e2e/
        └── loop_test.dart                           (31 e2e loop tests)
```

Untouched:

- `lib/core/engine.dart`, `constants.dart`, `skill_data.dart`,
  `topic_data.dart`, `prompts.dart` — pure-Dart engine.
- `supabase/migrations/*.sql`, `supabase/seed/*.sql`,
  `supabase/functions/llm-proxy/` — no schema or function change needed.

---

## 8. Setup checklist for a fresh device

1. **Enable Anonymous Sign-Ins in Supabase** (one-time, per project):
   - Dashboard → **Authentication** → **Sign In / Providers**.
   - Find **Anonymous Sign-Ins** → toggle **ON** → Save.
   - Verify by opening Auth → Users; after the app launches, an anonymous
     user row should appear.

2. **Build the APK** (from `ella_app/`):
   ```powershell
   cd c:\Users\dhans\StudioProjects\ella_flutter\ella_app
   flutter build apk --release
   ```

3. **Install on the phone:**
   - Transfer `build/app/outputs/flutter-apk/app-release.apk` to the phone.
   - Tap to install. Allow "install from unknown sources" if prompted.
   - On first launch, allow the **Microphone** permission.

4. **Verify end-to-end:**
   - Open Glass Box → Memory tab → no red banner; `child_id` is a real UUID.
   - Supabase → `auth.users` → one anonymous row exists.
   - Supabase → `children` → one row, `auth_user_id == child_id`.
   - Send Zoe a few turns → End ⚖️ → check `transcripts`, `session_logs`,
     `memory_state` for new/updated rows.
   - Glass Box → Session tab → expand a row → JSON includes the
     `transcript` array of `{speaker, text}` turns.

---

## 9. Verification commands

From `ella_app/`:

```powershell
dart analyze lib/           # → No issues found
flutter test                # → 99 / 99 pass
flutter build apk --release # → app-release.apk (~51 MB)
```

## 10. Out of scope (deliberate)

These are flagged for separate work:

- Email / OAuth sign-in. Anonymous is enough for testing. Replace
  `signInAnonymously()` with `signInWithPassword()` or OTP when ready.
- Persisting `interests` to the `children` table. Currently in-memory only.
- Dropping the `_TEST_` RLS policies and routing all writes through a
  service-role edge function (Section B of `002_rls.sql`). The current setup
  is the testing-phase override; production should use the service-role path.
- Production signing config for the APK
  (`android/app/build.gradle.kts` + `android/key.properties`).
- Mobile-runtime LLM provider switching (the simulator's ⚙️ LLM tab). The
  Android app uses the edge proxy only.
