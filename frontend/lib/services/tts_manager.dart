import 'package:flutter/foundation.dart';
import 'tts_service.dart';
import 'system_tts_service.dart';
import 'piper_tts_service.dart';

enum TtsEngineType { system, piper }

/// Manages dual TTS engines — Piper (primary) with system TTS fallback.
class TtsManager {
  final SystemTtsEngine _systemEngine = SystemTtsEngine();
  final PiperTtsEngine _piperEngine = PiperTtsEngine();

  TtsEngineType _activeType = TtsEngineType.system;
  bool _piperAvailable = false;

  TtsEngine get activeEngine =>
      _activeType == TtsEngineType.piper ? _piperEngine : _systemEngine;

  TtsEngineType get activeType => _activeType;
  bool get piperAvailable => _piperAvailable;
  bool get isSpeaking => activeEngine.isSpeaking;

  PiperTtsEngine get piperEngine => _piperEngine;

  Future<void> initialize() async {
    await _systemEngine.initialize();
    await _piperEngine.initialize();
    _piperAvailable = await _piperEngine.isAvailable;

    // Auto-select Piper if available
    // NOTE: System TTS (Google) generally sounds more natural on Android.
    // Keep system as default; Piper can be enabled manually if preferred.
    _activeType = TtsEngineType.system;
    if (_piperAvailable) {
      debugPrint('TTS: Piper available but using system TTS as default for better quality');
    } else {
      debugPrint('TTS: Piper not available, using system TTS');
    }
  }

  void setEngine(TtsEngineType type) {
    if (type == TtsEngineType.piper && !_piperAvailable) {
      debugPrint('TTS: Piper not available, staying on system');
      return;
    }
    _activeType = type;
  }

  Future<void> speak(String text) async {
    try {
      await activeEngine.speak(text);
    } catch (e) {
      // Fallback to system TTS if Piper fails
      if (_activeType == TtsEngineType.piper) {
        debugPrint('TTS: Piper failed, falling back to system: $e');
        await _systemEngine.speak(text);
      }
    }
  }

  Future<void> stop() async {
    await activeEngine.stop();
  }

  /// Refresh Piper voice models (call after adding new .onnx files).
  Future<void> refreshPiperVoices() async {
    await _piperEngine.refreshVoices();
    _piperAvailable = await _piperEngine.isAvailable;
  }

  void dispose() {
    _systemEngine.dispose();
    _piperEngine.dispose();
  }
}
