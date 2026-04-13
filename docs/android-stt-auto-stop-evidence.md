# Android SpeechRecognizer Auto-Stop Issue — Evidence & References

## The Problem

Android's built-in `SpeechRecognizer` automatically stops listening after a brief silence (typically 2–5 seconds). The official API provides extras to control silence timeouts, but they are unreliable or completely ignored by most recognizer implementations, including Google's own.

This is a platform-level limitation that has existed since Android 4.1 (Jelly Bean) and remains unresolved.

---

## Official Documentation

### 1. RecognizerIntent — Android Developer Docs
**Link:** https://developer.android.com/reference/android/speech/RecognizerIntent

Three silence-related extras are defined:
- `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS`
- `EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS`
- `EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS`

The docs explicitly state: *"depending on the recognizer implementation, these values may have no effect."*

### 2. RecognitionListener — Android Developer Docs
**Link:** https://developer.android.com/reference/android/speech/RecognitionListener

`onEndOfSpeech()` is called when the recognizer decides the user stopped speaking. There is no API to override or extend the silence timeout from the app side.

### 3. RecognizerIntent Source Code — AOSP
**Link:** https://android.googlesource.com/platform/frameworks/base.git/+/9066cfe9886ac131c34d59ed0e2d287b0e3c0087/core/java/android/speech/RecognizerIntent.java

The original source confirms the extras are hints, not guarantees.

---

## Stack Overflow Evidence

### 4. SpeechRecognizer stops automatically — need continuous listening
**Link:** https://stackoverflow.com/questions/57673683/android-speech-recognizer-stops-automatically-need-to-implement-like-google-bo

> "SpeechRecognizer stopped listening automatically in few seconds... working fine until user takes a pause while speaking."

### 5. EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS not working
**Link:** https://stackoverflow.com/questions/36519804/recognizerintent-extra-speech-input-complete-silence-length-millis-not-working

> "I know this has been an issue tracked since the release of Jelly Bean."

Confirms the official silence extras are ignored by Google's recognizer.

### 6. How can I make speech recognition listen forever?
**Link:** https://stackoverflow.com/questions/62129117/how-can-i-make-speech-recognition-listen-forever

> "The application still closes after 2 seconds of silence if something is said before the silence."

### 7. Android speech recognition has a very short timeout when the speaker pauses
**Link:** https://stackoverflow.com/questions/76623084/android-speech-recognition-has-a-very-short-timeout-when-the-speaker-pauses

> "If there is silence for (let's say 3 seconds) then it automatically exits because there hasn't been any speech spoken. That's what speech timeout means."

### 8. How to increase the amount of time Android speech recognition listens for?
**Link:** https://stackoverflow.com/questions/66319334/how-to-increase-the-amount-of-time-android-speech-recoognition-listens-for

> "Even after doing all that it still sometimes stops listening after one second of silence. There is no consistency."

### 9. Android extras about speech recognition does not work
**Link:** https://stackoverflow.com/questions/15660805/android-extras-about-speech-recognition-does-not-work

> "The default recognizer service listens about 10 seconds."

Confirms extras have no effect on Google's implementation.

### 10. Hack for EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS?
**Link:** https://stackoverflow.com/q/38933196

Developers actively looking for workarounds since the official API doesn't work.

### 11. Google Android speech capture timeout
**Link:** https://stackoverflow.com/questions/56648188/google-android-speech-capture-timeout

> "The 'complete silence' fields in the RecognizerIntent don't seem to make any difference. On certain devices it times out very quickly."

### 12. Android speech time out
**Link:** https://stackoverflow.com/questions/54196738/android-speech-time-out-speech-recognition

> "It only takes about 5 seconds before the speech timeout error is called which stops the speech recogniser."

---

## GitHub Issues (Cross-Platform Confirmation)

### 13. react-native-voice: Voice recognition stops automatically after few seconds
**Link:** https://github.com/react-native-voice/voice/issues/402

> "In Android the voice recognition stops automatically after 3 to 4 seconds. It is not activating again when we speak."

### 14. speech_to_text Flutter: Timeout resulting in error_no_match
**Link:** https://github.com/csdcorp/speech_to_text/issues/114

Flutter-specific confirmation of the same auto-stop behavior.

### 15. react-native-voice: EXTRA_SPEECH_INPUT options are not recognized
**Link:** https://github.com/react-native-voice/voice/issues/251

> "According to Android Developer API, these options manage the amount of silence time, before considering a speech is over or not."

Confirms the extras are defined but not honored.

### 16. Flutter speech-to-text plugin automatically stops capturing audio
**Link:** https://stackoverflow.com/questions/75692142/flutter-speech-to-text-plugin-automatically-stops-capturing-audio

Same issue reported in Flutter context.

---

## Summary

| Aspect | Detail |
|--------|--------|
| **Root cause** | Google's SpeechRecognizer implementation ignores silence timeout extras |
| **Since** | Android 4.1 (Jelly Bean), ~2012 |
| **Official stance** | Docs say extras "may have no effect" — by design |
| **Typical timeout** | 2–5 seconds of silence triggers auto-stop |
| **Affected platforms** | Native Android, Flutter, React Native, Xamarin — any framework using Android's SpeechRecognizer |
| **Workarounds** | 1. Restart recognizer on silence (auto-restart loop) |
| | 2. Use on-device STT engine (Whisper, Sherpa ONNX, Vosk) with full control |
| | 3. Use cloud STT APIs (Google Cloud Speech, Azure) with streaming |
