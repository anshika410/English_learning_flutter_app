# Ella — Project Summary

Voice-first English learning app for Indian students (ages 10–18), built by NavGurukul. Students speak to an AI tutor called Zoe/Ella. There is no typing — the core loop is: Zoe speaks → student responds by voice → Zoe replies.

---

## Stack

- **Flutter** (Android-first, also iOS/macOS)
- **State:** Provider (`ChangeNotifier`) — `ChatProvider` owns conversation state
- **TTS:** `flutter_tts` (system) + Piper (on-device neural), abstracted via `TtsManager`
- **STT:** `speech_to_text` (system) + Whisper (on-device), abstracted via `SttService` / `WhisperSttService`
- **LLM:** HTTP calls to Gemini or OpenAI — configured via `.env`, orchestrated by `LlmService`
- **Firebase:** Core init only (no Firestore/Auth in use yet)
- **Fonts:** Chillax (local asset), Baloo 2 / Kalam / Inconsolata / Fredoka (Google Fonts)

---

## Screen Flow

```
WelcomeScreen
  → PlacementScreen   (3-turn voice placement test)
    → ResultScreen    (CEFR level + feedback)
      → HomeScreen    (topic hub)
        → ConversationScreen  (main voice conversation)
          → EndScreen         (session summary)
            → HomeScreen (loop)
```

`ChatScreen` is a dev/debug screen — simpler Material UI, used for testing services.

---

## Key Files

| File | Role |
|---|---|
| `lib/main.dart` | Entry point — Firebase init, `.env` load, `runApp` |
| `lib/theme/ella_theme.dart` | All colour tokens (`EllaColors`) + Material theme (`EllaTheme`) |
| `lib/screens/welcome_screen.dart` | Intro with TTS, letter-by-letter animation, corner block decorations |
| `lib/screens/placement_screen.dart` | 3-turn placement test; local state, TTS+STT loop |
| `lib/screens/result_screen.dart` | CEFR result display; Mango level badge, Kalam feedback text |
| `lib/screens/home_screen.dart` | Topic chip hub; navigates to ConversationScreen with topic |
| `lib/screens/conversation_screen.dart` | Main conversation UI; consumes ChatProvider |
| `lib/screens/end_screen.dart` | Session summary; draggable transcript sheet |
| `lib/widgets/ella_primary_button.dart` | Stamp-shadow CTA button with press-depth animation |
| `lib/widgets/chat_bubble.dart` | Message bubble (used in ChatScreen) |
| `lib/providers/chat_provider.dart` | Conversation state — messages, STT/TTS/LLM orchestration |
| `lib/services/tts_manager.dart` | TTS abstraction — selects System vs Piper engine |
| `lib/services/stt_service.dart` | System STT wrapper (`speech_to_text`) |
| `lib/services/whisper_stt_service.dart` | On-device Whisper STT |
| `lib/services/llm_service.dart` | LLM API calls — Gemini/OpenAI, latency tracking |
| `lib/models/chat_message.dart` | Message model with role, content, correction, latency |
| `lib/models/placement_result.dart` | CEFR level, label, highlight text |

---

## Key Patterns

**Colours:** Always use `EllaColors.*` — never hardcode hex values. See `docs/ella-design-system-v3.md`.

**Buttons:** Use `EllaPrimaryButton` for all CTAs. It has the stamp-shadow press-depth animation built in.

**Mascot animations:** Zoe has three states (`speaking`, `listening`, `thinking`) mapped to `.webp` assets in `assets/mascot-animations/`. State is tracked as a local enum in each screen.

**TTS/STT services:** PlacementScreen injects `SttService` directly and calls `TtsManager` for playback. ConversationScreen delegates entirely to `ChatProvider`.

**LLM:** `LlmService.chat()` takes a list of `ChatMessage` and returns a string response. Provider and API key are loaded from `.env` at runtime.

**Latency:** Every conversation turn records STT / LLM / TTS durations in `LatencyInfo`, attached to each `ChatMessage`. Visible in ChatScreen debug view.

---

## Implemented Screens (as of April 2026)

- WelcomeScreen — TTS intro, letter-by-letter type animation, animated corner blocks, confetti background
- PlacementScreen — voice conversation loop, keyboard fallback, mascot state machine, concentric circle background
- ResultScreen — CEFR level badge, success pulse ring, Kalam feedback card
- HomeScreen — topic chips, avatar, "Talk to Zoe" CTA
- ConversationScreen — real-time STT, LLM responses, TTS, scaffold pills, mic pulse animation
- EndScreen — mock transcript, draggable bottom sheet

## Not Yet Implemented

- Real conversation history persistence
- Interests / topic selection path
- Progress tracking, streaks, level-up screens
- Grape colour family (no screen uses it yet)
- Ruled-line conversation background texture
- Challenge cards, path cards
