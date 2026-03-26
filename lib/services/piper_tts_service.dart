import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'tts_service.dart';
import 'voice_model_manager.dart';

/// Piper TTS engine — uses platform channels to run native ONNX inference.
/// Supports multiple accent/voice models that can be swapped at runtime.
class PiperTtsEngine extends TtsEngine {
  static const _channel = MethodChannel('piper_tts');
  final AudioPlayer _player = AudioPlayer();
  final VoiceModelManager _modelManager = VoiceModelManager();

  bool _isSpeaking = false;
  bool _nativeAvailable = false;
  PiperVoice? _currentVoice;
  List<PiperVoice> _availableVoices = [];

  @override
  String get name => 'Piper TTS';

  @override
  bool get isSpeaking => _isSpeaking;

  PiperVoice? get currentVoice => _currentVoice;
  List<PiperVoice> get availableVoices => List.unmodifiable(_availableVoices);

  @override
  Future<void> initialize() async {
    _player.playerStateStream.listen((state) {
      _isSpeaking = state.playing;
    });

    // Check native availability
    try {
      _nativeAvailable = await _channel.invokeMethod<bool>('isAvailable') ?? false;
      debugPrint('Piper: Native available: $_nativeAvailable');
    } catch (e) {
      debugPrint('Piper: Failed to check availability: $e');
      _nativeAvailable = false;
    }

    if (!_nativeAvailable) return;

    // Copy bundled models and scan
    await _modelManager.copyBundledModels();
    _availableVoices = await _modelManager.scanVoices();

    // Auto-load first voice
    if (_availableVoices.isNotEmpty) {
      await setVoice(_availableVoices.first);
    }
  }

  @override
  Future<bool> get isAvailable async {
    return _nativeAvailable && _availableVoices.isNotEmpty;
  }

  /// Set and load a voice model via the platform channel.
  Future<void> setVoice(PiperVoice voice) async {
    try {
      final success = await _channel.invokeMethod<bool>('loadModel', {
        'modelPath': voice.modelPath,
        'configPath': voice.configPath,
      });
      if (success == true) {
        _currentVoice = voice;
        debugPrint('Piper: Loaded voice: ${voice.label}');
      }
    } catch (e) {
      debugPrint('Piper: Failed to load voice ${voice.id}: $e');
    }
  }

  /// Reload models (e.g. after user adds new .onnx files).
  Future<void> refreshVoices() async {
    _availableVoices = await _modelManager.scanVoices();
    debugPrint('Piper: Refreshed, found ${_availableVoices.length} voice(s)');
  }

  @override
  Future<void> speak(String text) async {
    if (_currentVoice == null || !_nativeAvailable) {
      throw Exception('Piper TTS not available or no voice loaded');
    }
    if (_isSpeaking) await stop();

    _isSpeaking = true;
    try {
      final wavPath = await _channel.invokeMethod<String>('synthesize', {
        'text': text,
      });

      if (wavPath == null || wavPath.isEmpty) {
        throw Exception('Synthesis returned empty path');
      }

      debugPrint('Piper: Playing WAV from $wavPath');
      await _player.setFilePath(wavPath);
      await _player.play();
    } catch (e) {
      debugPrint('Piper: Error during speak: $e');
      _isSpeaking = false;
      rethrow; // Let TtsManager catch and fall back
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _isSpeaking = false;
  }

  @override
  void dispose() {
    _player.dispose();
  }
}
