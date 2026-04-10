# Ella

Voice-first English learning app for Indian students. Students speak to an AI tutor (Zoe) — no typing required.

**Platform:** Android-first Flutter · **Org:** NavGurukul

---

## For Claude / New Contributors — Read This First

Before reading any code, start here:

| Document                                                 | When to read it                                                                   |
| -------------------------------------------------------- | --------------------------------------------------------------------------------- |
| [`docs/project-summary.md`](docs/project-summary.md)     | Architecture, screen flow, key files, key patterns — read once to orient yourself |
| [`docs/zoe-design-system.md`](docs/zoe-design-system.md) | Colour tokens, typography, shadows, component specs — check when touching UI      |

**Rule of thumb:** Only open code files when you actually need to change something. The project summary gives you enough context to navigate without reading every screen upfront.

---

## Running the App

```bash
flutter pub get
flutter run
```

Requires a `.env` file in the project root with LLM API keys (Gemini or OpenAI). Copy `.env.example` if it exists, or ask Narendra for the keys.

---

## Branches

- `main` — stable
- Feature work lives on topic branches (e.g. `conversation-flow`)

---

## Project Structure

```
lib/
  screens/       # One file per screen
  widgets/       # Shared UI components
  services/      # TTS, STT, LLM abstractions
  providers/     # ChatProvider (conversation state)
  models/        # ChatMessage, PlacementResult, LatencyInfo
  theme/         # EllaColors + EllaTheme
docs/
  project-summary.md
  ella-design-system-v3.md
assets/
  mascot-animations/   # Zoe .webp animations
  chillax/             # Chillax font files
  piper_voices/        # Piper TTS models
  whisper/             # Whisper STT model
```
