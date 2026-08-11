# Conversation Feeling Check-In

After every 2nd completed conversation, Zoe asks the student how the conversation felt — **Not Great / Okay / Great**, shown left-to-right in that order. The answer is saved locally on-device (`SharedPreferences`) and logged as a Firebase Analytics event.

This is a first, UI-only version scoped to validate the UX and collect initial usage data without introducing a new backend API or database schema. Backend persistence (a real endpoint + DB columns) is intentionally deferred to a follow-up PR, pending what the analytics data shows.

## Flow

1. Student finishes a conversation → `_handleConversationEnded` in [`ella_app/lib/app.dart:382-405`](../ella_app/lib/app.dart#L382-L405) checks `shouldShowFeelingCheckIn(conversationNumber)`.
2. Gating rule — [`ella_app/lib/models/conversation_feedback.dart:34-35`](../ella_app/lib/models/conversation_feedback.dart#L34-L35): shown when `conversationNumber >= 2 && conversationNumber % 2 == 0` (every 2nd conversation — 2, 4, 6, 8, …).
3. If shown, pushes `FeelingCheckInScreen`; on `onComplete` it's replaced with `GardenScreen`. If not shown, goes straight to `GardenScreen`.
4. Student taps an emoji (Not Great / Okay / Great) in [`FeelingCheckInScreen._select`](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L93-L138), which:
   - Saves the answer to `SharedPreferences` (`_persistFeeling`, fire-and-forget)
   - Logs a Firebase Analytics event (fire-and-forget)
   - Shows the emoji's reaction pose (joyful/affirming/concerned) alone for ~1s, then shows the acknowledgement bubble and switches the mascot to `ZoeMascotMode.speaking` while the acknowledgement line plays, then returns to the reaction pose for a final ~1s hold before calling `widget.onComplete()` — navigation never races ahead of Zoe still speaking (`_speakAcknowledgement` is awaited before the post-speech hold; it swallows its own TTS errors, so a TTS failure can't hang the transition)

Mascot mode priority is: **speaking always wins** — `_MascotStage._mode` ([feeling_check_in_screen.dart:253-260](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L253-L260)) checks `speaking` first regardless of whether a feeling is selected, falling back to the reaction pose (or idle) only when nothing is being spoken. This covers both the initial greeting ("Hey {name}! How did the conversation feel?") and the post-selection acknowledgement — Zoe visibly speaks for the full duration of both lines.

## Screens / Files to Review

| Area | File | Lines |
|---|---|---|
| Screen UI + state machine + local persistence | [`ella_app/lib/screens/child_view/feeling_check_in_screen.dart`](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart) | whole file |
| Navigation trigger (gating + routing) | [`ella_app/lib/app.dart`](../ella_app/lib/app.dart) | 382–405 |
| Gating rule + emoji order + data model | [`ella_app/lib/models/conversation_feedback.dart`](../ella_app/lib/models/conversation_feedback.dart) | whole file |
| Firebase Analytics event | [`ella_app/lib/services/analytics_service.dart`](../ella_app/lib/services/analytics_service.dart) | 609–621 (`logConversationFeelingSubmitted`) |
| Flutter widget tests | [`ella_app/test/screens/feeling_check_in_screen_test.dart`](../ella_app/test/screens/feeling_check_in_screen_test.dart) | whole file |
| Related: completed-conversation counter (feeds gating) | [`backend/app/routers/users.py`](../backend/app/routers/users.py) | `_completed_conversation_count`, `_to_memory_response` |

## Emoji Order

`ConversationFeeling` is declared `notGreat, okay, great` ([conversation_feedback.dart:1-9](../ella_app/lib/models/conversation_feedback.dart#L1-L9)). The choice row (`_FeelingChoices`) renders by iterating `ConversationFeeling.values`, so declaration order drives on-screen layout directly — no separate ordering logic exists. `apiValue` strings (`'not_great'`, `'okay'`, `'great'`) are independent of declaration order, so the backend, stored data, and analytics payloads are unaffected by reordering.

## Question Text Style

"How did this conversation feel?" uses `EllaTextStyles.titleMedium` (24px/weight 700) ([feeling_check_in_screen.dart:216](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L216)) — between `titleSmall` (20px) and the greeting's `headline` (32px, which read as too large for this line). `maxLines: 2`.

## Local Storage

- No backend API or DB schema in this first version — the answer is written to `SharedPreferences` under the key `conversation_feeling.<sessionId>`, as a JSON string of `{"feeling": "great" | "okay" | "not_great", "submitted_at": "<ISO 8601 UTC>"}` ([`_persistFeeling`](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L141-L155)).
- Fire-and-forget, same as the previous backend call: a write failure is caught and only `debugPrint`-logged, never blocks the UX.
- Once the Firebase Analytics data validates the UX, real backend persistence (endpoint + DB columns) can be added in a follow-up PR — the `sessionId`-keyed storage shape is chosen to make that migration straightforward.

## Firebase Event

- Event name: `conversation_feeling_submitted`
- Params: `answer` (`great`/`okay`/`not_great`), `conversation_number`, `end_reason` (`automatic`/`manual`)
- Fired via `AnalyticsService.logConversationFeelingSubmitted` ([analytics_service.dart:609-621](../ella_app/lib/services/analytics_service.dart#L609-L621)), which wraps `FirebaseAnalytics.instance.logEvent`.
- Also logs a screen view `"Conversation Feeling Check-In"` on screen mount ([feeling_check_in_screen.dart:65](../ella_app/lib/screens/child_view/feeling_check_in_screen.dart#L65)).

## What Reviewers Should Check

1. `_persistFeeling` writes to `SharedPreferences` keyed by session id — confirm the JSON shape (`feeling` + `submitted_at`) is what a future backend-sync PR would expect to read back.
2. Frontend save is fire-and-forget (`unawaited(_persistFeeling(...))`) — a failed save is swallowed (`debugPrint` only) and doesn't block the UX. Confirm that's the intended tradeoff (no retry/queue) for a local write.
3. Gating math (`conversationNumber >= 2 && conversationNumber % 2 == 0`) matches product's intended cadence.
4. Question text at 24px doesn't crowd the layout on small devices, given it sits directly above the 3-emoji row on the same scrollable screen.
5. Mascot speaking state: covered by `mascot shows the speaking mode while the acknowledgement plays` in [`feeling_check_in_screen_test.dart`](../ella_app/test/screens/feeling_check_in_screen_test.dart) — confirms the mascot enters `ZoeMascotMode.speaking` while the acknowledgement plays and returns to the reaction pose once it finishes. The greeting phase was already covered by `speaks the personalized prompt once when mounted`.
