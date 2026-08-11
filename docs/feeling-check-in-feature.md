# Conversation Feeling Check-In

After every 2nd completed conversation, Zoe asks the student how the conversation felt (Not Great / Okay / Great, in that left-to-right order). The answer is persisted on the conversation record and logged as a Firebase Analytics event. Introduced in commit `1ce8289` ("conversation feedback").

## Status

- `1397f72` — "fix: wait for acknowledgement TTS before advancing past feeling check-in": sequencing fix so navigation to Garden waits for the acknowledgement voice line to finish, plus a copy tweak. Committed on `garden-ui`.
- `262004e` — merge of `origin/feature/full-backend-integration` (91 commits) into `garden-ui`. Both pushed to `origin/garden-ui` on 2026-08-11. See [Merge Notes](#merge-notes) below for what that merge touched in this feature's files.
- Uncommitted (as of this doc update): emoji order flipped to Not Great → Okay → Great, cadence changed to every 2nd conversation, and the question text now matches the greeting's size. See [Emoji Order, Cadence & Question Size Update](#emoji-order-cadence--question-size-update) below.

## Flow

1. Student finishes a conversation → `_handleConversationEnded` in [`ella_app/lib/app.dart:382-405`](../ella_app/lib/app.dart#L382-L405) checks `shouldShowFeelingCheckIn(conversationNumber)`.
2. Gating rule — [`ella_app/lib/models/conversation_feedback.dart:34-35`](../ella_app/lib/models/conversation_feedback.dart#L34-L35): shown when `conversationNumber >= 2 && conversationNumber % 2 == 0` (every 2nd conversation).
3. If shown, pushes `FeelingCheckInScreen`; on `onComplete` it's replaced with `GardenScreen`. If not shown, goes straight to `GardenScreen`.
4. Student taps an emoji (Not Great / Okay / Great) in [`FeelingCheckInScreen._select`](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L93-L138), which:
   - Saves the answer to the backend (`_persistFeeling`, fire-and-forget)
   - Logs a Firebase Analytics event (fire-and-forget)
   - Plays an acknowledgement animation/VO, then calls `widget.onComplete()`

## Screens / Files to Review

| Area | File | Lines |
|---|---|---|
| Screen UI + state machine | [`ella_app/lib/screens/child_view/feeling_check_in_screen.dart`](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart) | whole file (new, 584 lines) |
| Navigation trigger (gating + routing) | [`ella_app/lib/app.dart`](../ella_app/lib/app.dart) | 382–405 |
| Gating rule + data model | [`ella_app/lib/models/conversation_feedback.dart`](../ella_app/lib/models/conversation_feedback.dart) | whole file (new) |
| Frontend → backend call | [`ella_app/lib/services/ella_api_service.dart`](../ella_app/lib/services/ella_api_service.dart) | 397–406 (`saveConversationFeeling`) |
| Firebase Analytics event | [`ella_app/lib/services/analytics_service.dart`](../ella_app/lib/services/analytics_service.dart) | 609–621 (`logConversationFeelingSubmitted`) |
| Flutter widget tests | [`ella_app/test/screens/feeling_check_in_screen_test.dart`](../ella_app/test/screens/feeling_check_in_screen_test.dart) | whole file (290 lines) |
| API endpoint | [`backend/app/routers/conversations.py`](../backend/app/routers/conversations.py) | 168–201 (`PUT /session/{session_id}/feeling`) |
| Admin/API response exposure | [`backend/app/routers/conversations.py`](../backend/app/routers/conversations.py) | 538–539 (`_conv_out` includes `student_feeling`, `feeling_submitted_at`) |
| Request/response schemas | [`backend/app/schemas/conversation.py`](../backend/app/schemas/conversation.py) | 29–41 |
| DB model fields | [`backend/app/models/conversation.py`](../backend/app/models/conversation.py) | 24–26 |
| Migration | [`backend/migrations/versions/d4c3a2b1f090_add_conversation_feeling.py`](../backend/migrations/versions/d4c3a2b1f090_add_conversation_feeling.py) | whole file (new) |
| Backend tests | [`backend/tests/test_conversation_feeling.py`](../backend/tests/test_conversation_feeling.py) | whole file (72 lines) |
| Related: completed-conversation counter (feeds gating) | [`backend/app/routers/users.py`](../backend/app/routers/users.py) | `_completed_conversation_count`, `_to_memory_response` |

## Backend Storage

- Two new nullable columns on `conversations`: `student_feeling VARCHAR(20)` and `feeling_submitted_at TIMESTAMPTZ` ([migration](../backend/migrations/versions/d4c3a2b1f090_add_conversation_feeling.py)).
- `PUT /session/{session_id}/feeling` accepts `{"feeling": "great" | "okay" | "not_great"}`, requires the requesting user to own the session (`_get_owned`), and is **idempotent**: repeating the same answer returns the original submission instead of re-writing `feeling_submitted_at` ([conversations.py:168-201](../backend/app/routers/conversations.py#L168-L201)).
- Note in the endpoint docstring: this intentionally runs ahead of manual-end scoring, since that judge pass runs in the background.

## Firebase Event

- Event name: `conversation_feeling_submitted`
- Params: `answer` (`great`/`okay`/`not_great`), `conversation_number`, `end_reason` (`automatic`/`manual`)
- Fired via `AnalyticsService.logConversationFeelingSubmitted` ([analytics_service.dart:609-621](../ella_app/lib/services/analytics_service.dart#L609-L621)), which wraps `FirebaseAnalytics.instance.logEvent`.
- Also logs a screen view `"Conversation Feeling Check-In"` on screen mount ([feeling_check_in_screen.dart:65](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L65)).

## Acknowledgement Timing Fix (`1397f72`)

- **Acknowledgement copy**: `"Thanks for telling me."` → `"Thanks for telling me how you feel!"` ([line 21](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L21); the `_AcknowledgementBubble` widget's own copy at line ~419 already said the longer version — this brings the spoken line in sync with the bubble text).
- **Timing/sequencing fix**: previously `unawaited(_speakAcknowledgement())` fired TTS in parallel with a fixed 1s visual hold, so navigation to Garden was paced by the delay alone regardless of how long the voice line took to play. The code now `await`s `_speakAcknowledgement()` before the second 1s hold ([lines 127-134](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L127-L134)), so the screen won't advance to Garden until Zoe has actually finished speaking the acknowledgement — avoids the screen transitioning away while she's still mid-sentence.
- No backend or analytics changes in this commit — review can focus on `feeling_check_in_screen.dart` alone. Existing widget tests (`TTS failure does not affect the visual pacing before exit`, `a pending feeling request never delays Garden`) exercise this exact timing path and passed against the change.
- `_speakAcknowledgement` catches its own errors ([line 88](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L88)), so `await`ing it still resolves even if `_tts.speak` throws — TTS failure can't hang the transition.

## Merge Notes (`262004e`)

`garden-ui` was merged with `origin/feature/full-backend-integration` (91 commits) to bring this branch back in sync with mainline backend/curriculum work. Two conflicts touched files this feature depends on — both resolved by keeping both sides' additions:

- **[`ella_app/lib/app.dart`](../ella_app/lib/app.dart)**: import-only conflict. `garden-ui` added `models/conversation_feedback.dart` and `screens/child_view/feeling_check_in_screen.dart`; the integration branch added `providers/placement_provider.dart`. Kept all three; dropped a duplicate `garden_provider.dart` import the incoming side reintroduced.
- **[`ella_app/lib/screens/child_view/topic_launcher.dart`](../ella_app/lib/screens/child_view/topic_launcher.dart)**: `startTopic()`'s `onConversationEnded` parameter conflicted — `garden-ui` had retyped it from `VoidCallback?` to `ValueChanged<ConversationEndContext>?` (needed to pass end-context into the feeling check-in gate), while the integration branch added an unrelated `selectionSource` parameter. Kept the new type and added `selectionSource` back in; `session_screen.dart`'s `onEnded` (already `ValueChanged<ConversationEndContext>?`) confirms the retyped signature is the correct one to keep.
- No conflicts in the feeling feature's own files (`feeling_check_in_screen.dart`, `conversation_feedback.dart`, `ella_api_service.dart`'s `saveConversationFeeling`, backend `conversations.py`'s feeling endpoint) — all merged clean. `flutter analyze` on the touched files showed no new errors, only pre-existing lint `info`s unrelated to this change.

## Emoji Order, Cadence & Question Size Update

Product-requested tweaks, applied in one pass:

- **Emoji order**: `ConversationFeeling` enum declaration reordered from `great, okay, notGreat` to `notGreat, okay, great` ([conversation_feedback.dart:1-9](../ella_app/lib/models/conversation_feedback.dart#L1-L9)). The choice row (`_FeelingChoices`) renders by iterating `ConversationFeeling.values`, so this single reorder flips the on-screen layout to Not Great → Okay → Great with no other code changes. `apiValue` strings (`'not_great'`, `'okay'`, `'great'`) are unchanged, so the backend, stored data, and analytics event payloads are unaffected — this is purely a display/UI change.
- **Cadence**: gating formula changed from every 3rd conversation to every 2nd — `conversationNumber >= 2 && conversationNumber % 2 == 0` ([conversation_feedback.dart:34-35](../ella_app/lib/models/conversation_feedback.dart#L34-L35)). Now triggers at conversation 2, 4, 6, 8, … instead of 3, 6, 9, ….
- **Question text size**: "How did this conversation feel?" now uses `EllaTextStyles.headline` (32px/weight 800) instead of `titleSmall` (20px/weight 700), matching the greeting text above it exactly ([feeling_check_in_screen.dart:216](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L216)). `maxLines: 2` and the existing color override are unchanged.
- Test coverage updated: the cadence unit test in [`feeling_check_in_screen_test.dart`](../ella_app/test/screens/feeling_check_in_screen_test.dart) now asserts the every-2nd-conversation rule. Per-feeling widget tests key off `apiValue`/`ValueKey`, not enum position, so they needed no changes for the reorder. The overflow tests (`does not overflow at $size with enlarged text`) still pass with the larger question text.

## What Reviewers Should Check

1. `PUT /session/{id}/feeling` — auth/ownership check via `_get_owned`, idempotency behavior.
2. Frontend save is fire-and-forget (`unawaited(_persistFeeling(...))`) — a failed save is swallowed (`debugPrint` only, [line 148](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L148)) and doesn't block the UX. Confirm that's the intended tradeoff (no retry/queue).
3. Gating math (`conversationNumber >= 2 && conversationNumber % 2 == 0`) matches product's intended cadence (every 2nd conversation).
4. The `topic_launcher.dart` merge resolution above — double-check `startTopic()` callers still compile and that `selectionSource` defaults sensibly for the feeling-check-in-triggering call path.
5. Visually confirm the larger (32px) question text doesn't crowd the layout on small devices, given it now sits directly above the 3-emoji row on the same scrollable screen.
6. Pre-existing, unrelated to this change: three widget tests (`okay`/`not_great selects...`, related `Thanks for telling me.` assertions) fail against a stale acknowledgement-copy expectation left over from an earlier commit — not something introduced by this update, but worth a cleanup pass.
