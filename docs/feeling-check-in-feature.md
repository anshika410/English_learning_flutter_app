# Conversation Feeling Check-In

After every 3rd completed conversation, Zoe asks the student how the conversation felt (Great / Okay / Not Great). The answer is persisted on the conversation record and logged as a Firebase Analytics event. Introduced in commit `1ce8289` ("conversation feedback").

## Status

Reviewed for this summary: a pending, **uncommitted** change on `garden-ui` in `ella_app` (`git diff` as of 2026-08-11) reorders the acknowledgement flow so the "Thanks for telling me..." line is *spoken* before the post-speech hold, instead of firing TTS in parallel with a fixed 1s pacing delay. Also tweaks the acknowledgement copy. See [Pending change](#pending-change-uncommitted) below.

## Flow

1. Student finishes a conversation → `_handleConversationEnded` in [`ella_app/lib/app.dart:378-402`](../ella_app/lib/app.dart#L378-L402) checks `shouldShowFeelingCheckIn(conversationNumber)`.
2. Gating rule — [`ella_app/lib/models/conversation_feedback.dart:34-35`](../ella_app/lib/models/conversation_feedback.dart#L34-L35): shown when `conversationNumber >= 3 && conversationNumber % 3 == 0` (every 3rd conversation).
3. If shown, pushes `FeelingCheckInScreen`; on `onComplete` it's replaced with `GardenScreen`. If not shown, goes straight to `GardenScreen`.
4. Student taps an emoji (Great / Okay / Not Great) in [`FeelingCheckInScreen._select`](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L93-L138), which:
   - Saves the answer to the backend (`_persistFeeling`, fire-and-forget)
   - Logs a Firebase Analytics event (fire-and-forget)
   - Plays an acknowledgement animation/VO, then calls `widget.onComplete()`

## Screens / Files to Review

| Area | File | Lines |
|---|---|---|
| Screen UI + state machine | [`ella_app/lib/screens/child_view/feeling_check_in_screen.dart`](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart) | whole file (new, 584 lines) |
| Navigation trigger (gating + routing) | [`ella_app/lib/app.dart`](../ella_app/lib/app.dart) | 378–402 |
| Gating rule + data model | [`ella_app/lib/models/conversation_feedback.dart`](../ella_app/lib/models/conversation_feedback.dart) | whole file (new) |
| Frontend → backend call | [`ella_app/lib/services/ella_api_service.dart`](../ella_app/lib/services/ella_api_service.dart) | 397–406 (`saveConversationFeeling`) |
| Firebase Analytics event | [`ella_app/lib/services/analytics_service.dart`](../ella_app/lib/services/analytics_service.dart) | 350–363 (`logConversationFeelingSubmitted`) |
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
- Fired via `AnalyticsService.logConversationFeelingSubmitted` ([analytics_service.dart:350-363](../ella_app/lib/services/analytics_service.dart#L350-L363)), which wraps `FirebaseAnalytics.instance.logEvent`.
- Also logs a screen view `"Conversation Feeling Check-In"` on screen mount ([feeling_check_in_screen.dart:65](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L65)).

## Pending Change (uncommitted)

Working-tree diff on `ella_app/lib/screens/child_view/feeling_check_in_screen.dart` (not yet committed):

- **Acknowledgement copy**: `"Thanks for telling me."` → `"Thanks for telling me how you feel!"` (line 21; the `_AcknowledgementBubble` widget's own copy at line ~419 already said the longer version — this brings the spoken line in sync with the bubble text).
- **Timing/sequencing fix**: previously `unawaited(_speakAcknowledgement())` fired TTS in parallel with a fixed 1s visual hold, so navigation to Garden was paced by the delay alone regardless of how long the voice line took to play. The new code `await`s `_speakAcknowledgement()` before the second 1s hold, so the screen won't advance to Garden until Zoe has actually finished speaking the acknowledgement — avoids the screen transitioning away while she's still mid-sentence.
- No backend or analytics changes in this diff — review can focus on `feeling_check_in_screen.dart` alone. Existing widget tests (`TTS failure does not affect the visual pacing before exit`, `a pending feeling request never delays Garden`) should be re-run against this change since they exercise the exact timing path being modified.

## What Reviewers Should Check

1. `PUT /session/{id}/feeling` — auth/ownership check via `_get_owned`, idempotency behavior.
2. Frontend save is fire-and-forget (`unawaited(_persistFeeling(...))`) — a failed save is swallowed (`debugPrint` only, [line 148](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L148)) and doesn't block the UX. Confirm that's the intended tradeoff (no retry/queue).
3. Gating math (`conversationNumber >= 3 && conversationNumber % 3 == 0`) matches product's intended cadence (every 3rd conversation, not the 3rd only).
4. With the pending change, confirm TTS failure still can't hang the transition — `_speakAcknowledgement` catches its own errors ([line 88](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L88)), so `await`ing it should still resolve even if `_tts.speak` throws.
