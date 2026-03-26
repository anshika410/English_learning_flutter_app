# Implementation Plan: Native Piper TTS

## Overview

Replace the placeholder `PiperTtsEngine` (which shells out to a `piper` binary via `Process.start`) with a fully native, on-device implementation using Flutter platform channels. Android (Kotlin/JNI) first, then iOS (Swift). The pipeline: text → eSpeak-ng phonemization → token ID mapping → ONNX Runtime inference → WAV → `just_audio` playback.

## Tasks

- [x] 1. Build configuration and asset setup
  - [x] 1.1 Update `android/app/build.gradle.kts` to add ONNX Runtime dependency and set `minSdk` to 24
    - Add `implementation("com.microsoft.onnxruntime:onnxruntime-android:latest.release")` to dependencies
    - Set `minSdk = 24` in `defaultConfig`
    - _Requirements: 10.1, 10.5_

  - [x] 1.2 Update `pubspec.yaml` to declare `assets/piper_voices/` directory
    - Add `- assets/piper_voices/` to the flutter assets section
    - _Requirements: 10.4_

  - [x] 1.3 Create asset directory structure and place voice model files
    - Create `assets/piper_voices/` directory
    - Copy `Indian_accent_1.onnx` and `Indian_accent_1.onnx.json` (renamed to `en_IN-custom-medium.onnx` / `en_IN-custom-medium.onnx.json`) into `assets/piper_voices/`
    - _Requirements: 7.1, 10.4_

  - [x] 1.4 Set up eSpeak-ng native libraries and data files for Android
    - Create `android/app/src/main/jniLibs/arm64-v8a/` and `armeabi-v7a/` directories
    - Place prebuilt `libespeakng.so` and `libespeakng_jni.so` in each architecture directory
    - Create `android/app/src/main/assets/espeak-ng-data/` with required data files (`en_dict`, `phondata`, `phonindex`, `phontab`, `intonations`)
    - _Requirements: 2.1, 10.2_

- [ ] 2. Checkpoint - Verify build configuration
  - Ensure the project compiles with the new dependencies and assets. Ask the user if questions arise.

- [x] 3. Android native Kotlin implementation
  - [x] 3.1 Create `PiperModelConfig` data class
    - Create `android/app/src/main/kotlin/org/navgurukul/ella/ella_flutter/PiperModelConfig.kt`
    - Parse `.onnx.json` config: `phonemeIdMap`, `sampleRate`, `noiseScale`, `lengthScale`, `noiseW`, `numSpeakers`, `speakerId`
    - _Requirements: 3.1, 4.4_

  - [x] 3.2 Create `EspeakPhonemizer` JNI wrapper
    - Create `android/app/src/main/kotlin/org/navgurukul/ella/ella_flutter/EspeakPhonemizer.kt`
    - Declare `external fun nativeInit(dataPath: String): Boolean` and `external fun nativePhonemize(text: String, voiceId: String): String`
    - Implement `phonemize(text: String): String` using `en-us` voice variant
    - Return descriptive error on init/phonemize failure
    - _Requirements: 2.2, 2.3, 2.4_

  - [x] 3.3 Create `espeak_jni.c` JNI bridge
    - Create `android/app/src/main/jni/espeak_jni.c`
    - Implement JNI functions that call eSpeak-ng C API (`espeak_Initialize`, `espeak_SetVoiceByName`, `espeak_TextToPhonemes`)
    - Add `CMakeLists.txt` for building the JNI bridge, linking against `libespeakng.so`
    - _Requirements: 2.1, 2.2_

  - [x] 3.4 Create `PiperTokenizer`
    - Create `android/app/src/main/kotlin/org/navgurukul/ella/ella_flutter/PiperTokenizer.kt`
    - Parse `phoneme_id_map` from `PiperModelConfig` into a `Map<String, List<Long>>` lookup
    - Implement `tokenize(phonemes: String): LongArray` with pad token (`_`) insertion between each phoneme and at start/end
    - Skip unknown phoneme characters with a warning log
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [ ]* 3.5 Write unit tests for `PiperTokenizer`
    - Test padding insertion (pad at start, between phonemes, at end)
    - Test unknown phoneme character skipping
    - Test empty input handling
    - _Requirements: 3.2, 3.3, 3.4_

  - [x] 3.6 Create `WavBuilder` utility
    - Create `android/app/src/main/kotlin/org/navgurukul/ella/ella_flutter/WavBuilder.kt`
    - Implement `floatToWav(samples: FloatArray, sampleRate: Int): ByteArray` — clamp to [-1.0, 1.0], scale by 32767, write RIFF WAV header (44 bytes) + PCM16 data
    - Implement `writeWavFile(samples, sampleRate, outputPath)` to write to temp file
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [ ]* 3.7 Write unit tests for `WavBuilder`
    - Test float clamping and PCM16 conversion
    - Test WAV header correctness (sample rate, channels, bits per sample)
    - _Requirements: 5.1, 5.2_

  - [x] 3.8 Create `PiperMethodHandler` and register in `MainActivity`
    - Create `android/app/src/main/kotlin/org/navgurukul/ella/ella_flutter/PiperMethodHandler.kt`
    - Register `MethodChannel("piper_tts")` in `MainActivity.configureFlutterEngine()`
    - Implement `onMethodCall` dispatching for `isAvailable`, `loadModel`, and `synthesize`
    - `isAvailable`: return whether ONNX Runtime and eSpeak-ng are loaded
    - `loadModel`: create `OrtSession` from `.onnx` path, parse config
    - `synthesize`: phonemize → tokenize → ONNX infer (input tensors: token IDs `int64[1,N]`, lengths `int64[1]`, scales `float[3]`) → extract float output → WavBuilder → return WAV path
    - Propagate errors as `result.error(code, message, details)`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 4.1, 4.2, 4.3, 4.5_

- [ ] 4. Checkpoint - Verify Android native pipeline
  - Ensure the Android native code compiles. Ask the user if questions arise.

- [x] 5. Dart layer rewrite
  - [x] 5.1 Create `VoiceModelManager` helper
    - Create `lib/services/voice_model_manager.dart`
    - Implement `copyBundledModels()`: copy assets from `assets/piper_voices/` to `<app_support>/piper/voices/` if not already present
    - Implement `scanVoices()`: scan `<app_support>/piper/voices/` for `.onnx` + `.onnx.json` pairs, return `List<PiperVoice>`
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 5.2 Rewrite `PiperTtsEngine` in `lib/services/piper_tts_service.dart`
    - Replace `Process.start` with `MethodChannel('piper_tts')` calls
    - `initialize()`: call `VoiceModelManager.copyBundledModels()`, `scanVoices()`, invoke `isAvailable` on channel, auto-load first voice via `loadModel`
    - `speak(text)`: invoke `synthesize` on channel, play returned WAV path via `just_audio` `AudioPlayer`
    - `setVoice(voice)`: invoke `loadModel` on channel with voice paths
    - `stop()`: stop `AudioPlayer`
    - Maintain `TtsEngine` interface contract (`name`, `isSpeaking`, `isAvailable`, `speak`, `stop`, `dispose`)
    - Throw on synthesis failure so `TtsManager` can fall back
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 7.4, 7.5_

  - [ ]* 5.3 Write unit tests for `VoiceModelManager`
    - Test voice scanning finds valid `.onnx` + `.onnx.json` pairs
    - Test skipping models with missing config files
    - _Requirements: 7.1, 7.3, 9.4_

- [ ] 6. Error handling and fallback verification
  - [ ] 6.1 Verify `TtsManager` fallback behavior
    - Confirm `TtsManager.speak()` catches Piper exceptions and falls back to `SystemTtsEngine` — no code changes expected, just verify existing logic handles the new exception paths
    - Confirm `TtsManager.initialize()` sets `_piperAvailable = false` when native side returns `isAvailable = false`
    - _Requirements: 9.1, 9.2, 9.3_

  - [ ]* 6.2 Write integration test for fallback
    - Test that when `synthesize` throws a `PlatformException`, `TtsManager` falls back to system TTS
    - _Requirements: 9.1, 9.2_

- [ ] 7. Checkpoint - Verify end-to-end Android flow
  - Ensure all tests pass and the Piper TTS pipeline works on Android. Ask the user if questions arise.

- [ ] 8. iOS native implementation
  - [ ] 8.1 Update `ios/Podfile` to add ONNX Runtime pod
    - Add `pod 'onnxruntime-objc'` to the Runner target
    - Set platform to iOS 13.0 minimum
    - _Requirements: 8.1, 10.3_

  - [ ] 8.2 Set up eSpeak-ng for iOS
    - Add eSpeak-ng as a prebuilt XCFramework or static library with bundled data files
    - Create bridging header for eSpeak-ng C API access from Swift
    - _Requirements: 8.2_

  - [ ] 8.3 Create iOS `PiperModelConfig` Swift struct
    - Create `ios/Runner/PiperModelConfig.swift`
    - Parse `.onnx.json` config into `PiperModelConfig` struct
    - _Requirements: 3.1, 4.4_

  - [ ] 8.4 Create iOS `EspeakPhonemizer` Swift class
    - Create `ios/Runner/EspeakPhonemizer.swift`
    - Wrap eSpeak-ng C API calls via bridging header
    - Implement `phonemize(text: String) -> String` using `en-us` voice
    - _Requirements: 8.2, 8.3_

  - [ ] 8.5 Create iOS `PiperTokenizer` Swift class
    - Create `ios/Runner/PiperTokenizer.swift`
    - Same tokenization logic as Kotlin version: phoneme → token IDs with padding
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ] 8.6 Create iOS `WavBuilder` Swift struct
    - Create `ios/Runner/WavBuilder.swift`
    - Same WAV conversion logic as Kotlin version
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [ ] 8.7 Create iOS `PiperMethodHandler` and register in `AppDelegate`
    - Create `ios/Runner/PiperMethodHandler.swift`
    - Register `FlutterMethodChannel(name: "piper_tts")` in `AppDelegate`
    - Implement same method dispatch: `isAvailable`, `loadModel`, `synthesize`
    - Use `onnxruntime-objc` for ONNX inference session
    - Return `false` for `isAvailable` if eSpeak-ng or ONNX Runtime fails to load
    - _Requirements: 8.1, 8.3, 8.4, 8.5_

- [ ] 9. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass on both platforms. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirement acceptance criteria (e.g., 3.2 = Requirement 3, criterion 2)
- Android is implemented first (tasks 3-4), then iOS follows the same pattern (task 8)
- The existing `TtsManager`, `TtsSettingsSheet`, and `ChatProvider` require no changes — only `PiperTtsEngine` internals change
- Voice model files (~60MB `.onnx`) need to be obtained separately and placed in `assets/piper_voices/`
- eSpeak-ng prebuilt `.so` / XCFramework binaries need to be compiled or obtained from the eSpeak-ng project
