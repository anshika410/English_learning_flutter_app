**Android STT–TTS System: Capabilities, Constraints & Product Recommendations**

---

**Executive Summary**

We evaluated Android's Speech-to-Text (STT) and Text-to-Speech (TTS) capabilities for building a voice-based learning experience. The core finding: **live transcription of short, turn-based speech works well on Android**. However, continuous listening, long-form speech, and full-duplex conversation are not reliably achievable due to platform-level constraints. This document covers what works, what doesn't, the trade-offs of each approach, and our recommended product direction.

**Bottom line:** Design for a turn-based speaking practice app. Do not pursue real-time conversational AI on the current Android STT stack.

---

**1. Why Live Transcription Matters**

Live transcription is the single most important capability for a natural-feeling speech experience. When users speak and see their words appear instantly via partial results, the interaction feels real-time and responsive. Without it, the experience feels delayed and broken — users won't wait for a full sentence to be processed before expecting feedback.

This means the system must rely on **partial/interim results** from the speech recognizer, not wait for final transcripts.

---

**2. What Works Well**

**Android STT for Short Speech**

Android's `SpeechRecognizer` provides two callbacks:
- `onPartialResults()` — delivers live, in-progress transcription
- `onResults()` — delivers the final transcript after the user stops speaking

For short utterances (1–5 seconds), this works reliably. Latency is low, partial results enable real-time UI updates, and the experience feels conversational.

**Android Default TTS**

Android's built-in TTS engine is reliable, low-latency, and works offline. Hindi accent quality is reasonable. This is recommended as the primary speech output solution.

**Piper TTS** is a viable alternative with more customization options — worth exploring later but not needed immediately.

---

**3. What Doesn't Work Well**

**Long Speech + Wait-for-Final Pattern**

If the product requires the user to speak for extended periods and then waits for a final transcript, the result is high latency, poor UX, and reduced accuracy. This pattern should be avoided.

**Continuous Listening**

Android's `SpeechRecognizer` automatically stops listening after a brief silence (typically 2–5 seconds). This is a hard platform constraint:

- Android exposes silence-related configuration extras (`EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS`, etc.), but these are **not guaranteed to be honored** by the recognizer implementation.
- `onEndOfSpeech()` fires automatically and cannot be overridden.
- This behavior is confirmed across native Android, React Native, and Flutter — it is a platform limitation, not a bug.

---

**4. The Restart Loop Workaround — Trade-offs**

The most common workaround for the auto-stop behavior is to detect `onEndOfSpeech()` or `onResults()` and immediately restart the recognizer. This creates a pseudo-continuous listening experience.

**What it solves:**
- Enables longer listening sessions
- Avoids hard session cut-offs

**What it breaks:**

- **Audible beep sound:** Android triggers a system sound on every mic restart. This is device-dependent (e.g., prominent on OnePlus devices), not fully controllable via APIs, and creates a disruptive beep loop during conversation. Mitigations like DND mode or audio permission resets are unreliable across devices.

- **Word loss during restart:** If the user is still speaking when the mic restarts, words get cut off or missed. This creates transcription gaps and confusion in fast-paced conversation.

**Verdict:** The restart loop works for controlled, turn-based interactions where pauses are expected. It is not viable for natural, uninterrupted conversation flows.

---

**5. Whisper as an Alternative**

**Current Whisper Flow:** Record → Process → Transcript → Send to LLM

Whisper offers higher accuracy, better handling of noise and accents, and is more suitable for longer speech segments. However, in its current setup it provides **no live transcription** — it's a batch process that adds delay.

**Whisper Streaming (Future Exploration)**

Whisper streaming is not yet implemented in our system. It could potentially enable near-real-time transcription with Whisper-level accuracy.

**Recommendation:** Build a small proof-of-concept to test Whisper streaming on Android. Evaluate latency, stability, and whether it can replace or complement the native STT for longer interactions.

---

**6. Decision Framework**

| Use Case | Recommended Approach |
|---|---|
| Short live conversation (1–5 sec) | Android STT with `onPartialResults` |
| Real-time UI feedback | Partial/interim results |
| Longer speech processing | Whisper (batch, no live feedback) |
| True conversational AI | Not supported on current stack |
| Future improvement | Whisper streaming POC |

---

**7. What This Means for Product**

| Product Direction | Feasibility |
|---|---|
| Speaking practice app (short sentences, turn-based) | Fully supported — ship it |
| Real-time conversational AI (continuous, full-duplex) | Not supported with current stack |

**What we can ship:** A turn-based speaking practice experience — user speaks short sentences, sees live transcription, receives a response. Works well on Android.

**What we should not promise:** Open-ended, continuous voice conversation. Platform constraints make this unreliable regardless of implementation quality.

**What would change the picture:** A server-side streaming STT pipeline (e.g., Whisper streaming, Deepgram) would bypass Android's `SpeechRecognizer` limitations. This is a potential future path but introduces latency, cost, and connectivity dependencies.

---

**8. Recommendation**

Proceed with:

1. **Android STT** using `onPartialResults` + restart logic for short, turn-based interactions
2. **Android default TTS** as the primary speech output
3. **Whisper** for batch processing of longer speech where live feedback is not required
4. **Whisper streaming POC** as a future exploration for near-real-time accuracy improvements

Design the product around turn-based interaction. Do not build toward continuous conversational AI on the current mobile-native STT stack.

---

**Appendix: Evidence Base**

**Official Documentation**
- RecognizerIntent — https://developer.android.com/reference/android/speech/RecognizerIntent
- RecognitionListener — https://developer.android.com/reference/android/speech/RecognitionListener
- Android Source (RecognizerIntent.java) — https://android.googlesource.com/platform/frameworks/base.git/+/9066cfe9886ac131c34d59ed0e2d287b0e3c0087/core/java/android/speech/RecognizerIntent.java

**Google Issue Tracker**
- Issue #486536250 — https://issuetracker.google.com/issues/486536250#comment2
  Confirms the silence timeout is a known issue with no reliable fix.

**Community Evidence (Stack Overflow)**
Confirmed across 10+ threads spanning 2013–2024. Consistent pattern: silence timeout is 2–5 seconds, configuration extras are ignored, no reliable workaround exists.

- Recognizer stops automatically — https://stackoverflow.com/questions/57673683
- Silence length extras not working — https://stackoverflow.com/questions/36519804
- Listen forever — https://stackoverflow.com/questions/62129117
- Very short timeout on pause — https://stackoverflow.com/questions/76623084
- Increase listening time — https://stackoverflow.com/questions/66319334
- Speech recognition extras not working — https://stackoverflow.com/questions/15660805
- Capture timeout — https://stackoverflow.com/questions/56648188
- Speech timeout — https://stackoverflow.com/questions/54196738
- Related discussion — https://stackoverflow.com/q/38933196

**Cross-Platform (GitHub Issues)**
Confirms the issue exists across all frameworks using Android STT:

- react-native-voice #402 — https://github.com/react-native-voice/voice/issues/402
- react-native-voice #251 — https://github.com/react-native-voice/voice/issues/251
- speech_to_text (Flutter) #114 — https://github.com/csdcorp/speech_to_text/issues/114
- Flutter speech_to_text auto-stop — https://stackoverflow.com/questions/75692142
