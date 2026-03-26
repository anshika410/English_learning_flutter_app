# Requirements Document

## Introduction

Ella is a Flutter-based English language learning app that uses STT, TTS, and LLM for conversational practice. Currently, TTS relies on the device's built-in system voice (`flutter_tts`). This feature replaces the placeholder Piper TTS engine with a fully native, on-device implementation that runs Piper voice models directly on the device using platform channels (Dart ↔ Kotlin on Android, Dart ↔ Swift on iOS). The pipeline is: Text → eSpeak-ng phonemization (IPA) → Token ID mapping (via `phoneme_id_map` from `.onnx.json`) → ONNX Runtime inference → Float audio → PCM 16-bit → WAV → Playback via `just_audio`. This enables custom-trained Indian English accent voices without any network dependency.

## Glossary

- **Piper_Engine**: The native on-device TTS engine that converts text to speech using Piper ONNX voice models, running natively on Android (Kotlin/JNI) and iOS (Swift)
- **Platform_Channel**: The Flutter MethodChannel bridge (`piper_tts`) that connects Dart code to native Android (Kotlin) and iOS (Swift) implementations
- **Phonemizer**: The eSpeak-ng native library component that converts English text into IPA phoneme sequences
- **Tokenizer**: The component that maps IPA phoneme strings to integer token ID sequences using the `phoneme_id_map` from the voice model's `.onnx.json` configuration file
- **ONNX_Runtime**: The on-device machine learning inference engine that executes the Piper `.onnx` voice model to produce raw float audio from token IDs
- **Voice_Model**: A pair of files (`.onnx` model + `.onnx.json` config) representing a trained Piper voice, approximately 60MB each
- **Model_Config**: The `.onnx.json` JSON file accompanying each voice model, containing `phoneme_id_map`, `sample_rate`, `noise_scale`, `length_scale`, `noise_w`, and other synthesis parameters
- **WAV_Builder**: The component that converts raw float audio samples from ONNX inference into a PCM 16-bit WAV byte array with proper RIFF headers
- **TTS_Manager**: The existing Dart class (`TtsManager`) that manages dual TTS engines (system and Piper) with automatic fallback
- **Voice_Scanner**: The component that discovers available `.onnx` + `.onnx.json` voice model pairs from the app's asset bundle or local storage

## Requirements

### Requirement 1: Platform Channel Bridge

**User Story:** As a developer, I want a platform channel bridge between Dart and native code, so that the Dart Piper TTS service can invoke native synthesis without spawning external processes.

#### Acceptance Criteria

1. THE Platform_Channel SHALL register a MethodChannel named `piper_tts` on both Android and iOS native sides during app startup
2. WHEN the Dart layer invokes the `synthesize` method with a text string and a model path, THE Platform_Channel SHALL delegate to the native Piper_Engine and return a WAV file path as a string
3. WHEN the Dart layer invokes the `isAvailable` method, THE Platform_Channel SHALL return a boolean indicating whether the native Piper_Engine dependencies (ONNX Runtime, eSpeak-ng) are loaded
4. IF the native side throws an exception during synthesis, THEN THE Platform_Channel SHALL propagate a PlatformException with an error code and descriptive message to the Dart layer
5. WHEN the Dart layer invokes the `loadModel` method with a model path and config path, THE Platform_Channel SHALL load the ONNX model into memory and parse the Model_Config for synthesis parameters

### Requirement 2: eSpeak-ng Phonemization (Android)

**User Story:** As a developer, I want eSpeak-ng integrated natively on Android, so that the Piper_Engine can convert English text into IPA phonemes without external process calls.

#### Acceptance Criteria

1. THE Piper_Engine on Android SHALL include eSpeak-ng as a prebuilt native library (`.so` files for arm64-v8a and armeabi-v7a architectures)
2. WHEN the Piper_Engine receives text for synthesis, THE Phonemizer SHALL convert the text into an IPA phoneme string using eSpeak-ng's C API via JNI
3. THE Phonemizer SHALL use the `en-us` voice variant for eSpeak-ng phonemization by default
4. IF eSpeak-ng fails to initialize or phonemize the input text, THEN THE Phonemizer SHALL return an error with a descriptive message indicating the failure reason

### Requirement 3: Token ID Mapping

**User Story:** As a developer, I want phoneme strings mapped to integer token IDs, so that the ONNX model receives correctly encoded input tensors.

#### Acceptance Criteria

1. WHEN a Model_Config is loaded, THE Tokenizer SHALL parse the `phoneme_id_map` dictionary from the `.onnx.json` file into an in-memory lookup structure
2. WHEN the Tokenizer receives an IPA phoneme string, THE Tokenizer SHALL convert each phoneme character to its corresponding integer token ID using the `phoneme_id_map`
3. THE Tokenizer SHALL insert padding token IDs (the `_` mapped value) between each phoneme token and at the start and end of the sequence, matching Piper's expected VITS input format
4. IF a phoneme character is not found in the `phoneme_id_map`, THEN THE Tokenizer SHALL skip that character and log a warning

### Requirement 4: ONNX Runtime Inference (Android)

**User Story:** As a developer, I want ONNX Runtime running natively on Android, so that the Piper voice model can generate audio from token IDs on-device.

#### Acceptance Criteria

1. THE Piper_Engine on Android SHALL include ONNX Runtime as a Gradle dependency (`com.microsoft.onnxruntime:onnxruntime-android`)
2. WHEN the `loadModel` method is called, THE ONNX_Runtime SHALL create an inference session from the specified `.onnx` file
3. WHEN the Piper_Engine performs synthesis, THE ONNX_Runtime SHALL accept input tensors (token IDs as `int64` array, token ID length as `int64`, scales as `float` array) and produce a float audio output tensor
4. THE Piper_Engine SHALL read `noise_scale`, `length_scale`, and `noise_w` values from the Model_Config and pass them as the scales input tensor
5. IF the ONNX inference session fails to load or run, THEN THE ONNX_Runtime SHALL throw an exception with a descriptive error message

### Requirement 5: Audio Conversion and WAV Output

**User Story:** As a developer, I want the raw float audio from ONNX inference converted to a playable WAV file, so that `just_audio` can play the synthesized speech.

#### Acceptance Criteria

1. WHEN ONNX inference produces a float audio array, THE WAV_Builder SHALL convert each float sample to a PCM 16-bit signed integer by clamping to [-1.0, 1.0] and scaling by 32767
2. THE WAV_Builder SHALL wrap the PCM 16-bit samples in a valid RIFF WAV header with the sample rate read from the Model_Config, 1 channel (mono), and 16 bits per sample
3. THE WAV_Builder SHALL write the resulting WAV data to a temporary file and return the file path
4. THE WAV_Builder SHALL use the `sample_rate` field from the Model_Config (typically 22050 Hz) for the WAV header

### Requirement 6: Dart Piper TTS Service Rewrite

**User Story:** As a developer, I want the existing `PiperTtsEngine` Dart class rewritten to use platform channels instead of `Process.start`, so that Piper TTS works on mobile devices.

#### Acceptance Criteria

1. THE Piper_Engine Dart class SHALL use a `MethodChannel('piper_tts')` to communicate with native code instead of spawning a `piper` binary process
2. WHEN `initialize()` is called, THE Piper_Engine SHALL invoke the platform channel `isAvailable` method and scan for bundled voice models in the Flutter asset bundle
3. WHEN `speak(text)` is called, THE Piper_Engine SHALL invoke the platform channel `synthesize` method, receive a WAV file path, and play it using the existing `just_audio` AudioPlayer
4. WHEN `setVoice(voice)` is called, THE Piper_Engine SHALL invoke the platform channel `loadModel` method with the new voice model's paths
5. THE Piper_Engine SHALL maintain the existing `TtsEngine` interface contract (`name`, `isSpeaking`, `initialize`, `isAvailable`, `speak`, `stop`, `dispose`) so that TTS_Manager requires no changes
6. IF the platform channel `synthesize` call fails, THEN THE Piper_Engine SHALL throw an exception so that TTS_Manager can fall back to system TTS

### Requirement 7: Voice Model Management

**User Story:** As a user, I want to switch between different accent/voice models, so that I can practice listening to different English accents.

#### Acceptance Criteria

1. THE Voice_Scanner SHALL discover voice model pairs (`.onnx` + `.onnx.json`) bundled as Flutter assets under the `assets/piper_voices/` directory
2. WHEN the app starts, THE Voice_Scanner SHALL copy bundled voice model files from the asset bundle to the app's local storage directory if they do not already exist there
3. THE Voice_Scanner SHALL also scan the app's local storage `piper/voices/` directory for additional voice models added at runtime
4. WHEN a user selects a different voice in the TTS settings UI, THE Piper_Engine SHALL load the selected Voice_Model via the platform channel `loadModel` method
5. THE Piper_Engine SHALL expose the list of available voices and the currently selected voice so that the existing `TtsSettingsSheet` widget can display them without modification

### Requirement 8: iOS Native Implementation

**User Story:** As a developer, I want Piper TTS working on iOS, so that the app provides the same custom voice experience on both platforms.

#### Acceptance Criteria

1. THE Piper_Engine on iOS SHALL include ONNX Runtime via a CocoaPods dependency (`onnxruntime-objc` or `onnxruntime-c`)
2. THE Piper_Engine on iOS SHALL include eSpeak-ng as a prebuilt static framework or XCFramework with bundled data files
3. WHEN the Dart layer invokes `synthesize` via the Platform_Channel, THE iOS native handler SHALL perform the same pipeline: phonemize → tokenize → ONNX infer → WAV build → return file path
4. THE iOS native handler SHALL register the `piper_tts` FlutterMethodChannel in `AppDelegate.swift` or a dedicated plugin class
5. IF eSpeak-ng or ONNX Runtime fails to load on iOS, THEN THE Platform_Channel SHALL return `false` for the `isAvailable` method

### Requirement 9: Error Handling and Fallback

**User Story:** As a user, I want the app to gracefully fall back to system TTS if Piper fails, so that I always hear spoken responses.

#### Acceptance Criteria

1. IF the Piper_Engine fails during `speak()`, THEN THE TTS_Manager SHALL catch the exception and invoke the SystemTtsEngine to speak the same text
2. IF the Piper_Engine reports `isAvailable` as false, THEN THE TTS_Manager SHALL default to the SystemTtsEngine and disable the Piper option in the TTS settings UI
3. WHEN the Piper_Engine encounters a synthesis error, THE Piper_Engine SHALL log the error details using `debugPrint` for diagnostic purposes
4. IF a Voice_Model file is corrupted or missing its paired config file, THEN THE Voice_Scanner SHALL skip that model and log a warning

### Requirement 10: Build Configuration

**User Story:** As a developer, I want the native dependencies properly configured in the build system, so that the app compiles and runs with Piper support on both platforms.

#### Acceptance Criteria

1. THE Android `build.gradle.kts` SHALL include the ONNX Runtime Android dependency in the app module's dependencies block
2. THE Android build SHALL package eSpeak-ng `.so` libraries and data files in the correct `jniLibs` and `assets` directories
3. THE iOS `Podfile` SHALL include the ONNX Runtime pod dependency
4. THE `pubspec.yaml` SHALL declare the `assets/piper_voices/` directory in the assets section for bundling voice models
5. THE Android `build.gradle.kts` SHALL set `minSdk` to at least 24 to satisfy ONNX Runtime Android requirements
