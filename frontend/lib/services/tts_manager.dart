import 'package:flutter/foundation.dart';
import 'tts_service.dart';
import 'system_tts_service.dart';
import 'piper_tts_service.dart';
import 'web_tts_service.dart';
import 'openai_tts_service.dart';

enum TtsEngineType { system, piper, web, openai }

/// Manages TTS engines:
///   - Web:     WebTtsEngine (browser SpeechSynthesis API)
///   - Android: SystemTtsEngine (default) with optional Piper fallback
class TtsManager {
  final SystemTtsEngine _systemEngine = SystemTtsEngine();
  final PiperTtsEngine _piperEngine = PiperTtsEngine();
  final WebTtsEngine _webEngine = WebTtsEngine();
  final OpenAiTtsEngine _openAiEngine = OpenAiTtsEngine();

  TtsEngineType _activeType = TtsEngineType.system;
  bool _piperAvailable = false;

  TtsEngine get activeEngine => switch (_activeType) {
        TtsEngineType.openai => _openAiEngine,
        TtsEngineType.web => _webEngine,
        TtsEngineType.piper => _piperEngine,
        TtsEngineType.system => _systemEngine,
      };

  TtsEngineType get activeType => _activeType;
  bool get piperAvailable => _piperAvailable;
  bool get isSpeaking => activeEngine.isSpeaking;

  PiperTtsEngine get piperEngine => _piperEngine;

  Future<void> initialize() async {
    if (kIsWeb) {
      // Web: prefer OpenAI TTS (natural voice), fall back to browser SpeechSynthesis
      await _openAiEngine.initialize();
      if (await _openAiEngine.isAvailable) {
        _activeType = TtsEngineType.openai;
        debugPrint('TTS: Web platform — using OpenAI TTS');
      } else {
        await _webEngine.initialize();
        _activeType = TtsEngineType.web;
        debugPrint('TTS: Web platform — using Web Speech API (no OpenAI key)');
      }
      return;
    }

    // Android/native: system TTS + optional Piper
    await _systemEngine.initialize();
    await _piperEngine.initialize();
    _piperAvailable = await _piperEngine.isAvailable;

    _activeType = TtsEngineType.system;
    if (_piperAvailable) {
      debugPrint('TTS: Piper available (using system TTS as default)');
    } else {
      debugPrint('TTS: Piper not available, using system TTS');
    }
  }

  void setEngine(TtsEngineType type) {
    if (kIsWeb) {
      // On web only openai and web engines are valid
      _activeType = (type == TtsEngineType.openai) ? TtsEngineType.openai : TtsEngineType.web;
      return;
    }
    if (type == TtsEngineType.piper && !_piperAvailable) {
      debugPrint('TTS: Piper not available, staying on system');
      return;
    }
    _activeType = type;
  }

  Future<void> speak(String text) async {
    try {
      await activeEngine.speak(text).timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );
    } catch (e) {
      // Fallback to system TTS if Piper fails (Android only)
      if (_activeType == TtsEngineType.piper) {
        debugPrint('TTS: Piper failed, falling back to system: $e');
        await _systemEngine.speak(text).timeout(
          const Duration(seconds: 15),
          onTimeout: () {},
        );
      }
    }
  }

  Future<void> stop() async {
    await activeEngine.stop();
  }

  /// Refresh Piper voice models (call after adding new .onnx files).
  Future<void> refreshPiperVoices() async {
    if (kIsWeb) return;
    await _piperEngine.refreshVoices();
    _piperAvailable = await _piperEngine.isAvailable;
  }

  void dispose() {
    _systemEngine.dispose();
    _piperEngine.dispose();
    _webEngine.dispose();
    _openAiEngine.dispose();
  }
}
