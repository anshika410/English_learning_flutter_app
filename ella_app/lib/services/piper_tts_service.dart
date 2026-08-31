import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'stt_tts_service.dart';
import 'piper_model_service.dart';
import 'audio_service.dart';

/// On-device TTS using the NavGurukul Indian accent Piper model via sherpa-onnx.
/// Falls back gracefully if model is not downloaded yet.
class PiperTtsService implements TtsInterface {
  sherpa.OfflineTts? _tts;
  bool _initialized = false;
  bool _speaking = false;

  final _doneController = StreamController<void>.broadcast();
  Stream<void> get doneStream => _doneController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final modelService = PiperModelService.instance;
      final downloaded = await modelService.checkIfDownloaded();
      if (!downloaded) {
        debugPrint('PiperTtsService: model not downloaded yet, skipping init');
        return;
      }

      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: modelService.modelOnnxPath!,
            lexicon: '',
            tokens: '',
            dataDir: '',
            noiseScale: 0.667,
            noiseScaleW: 0.8,
            lengthScale: 1.0,
          ),
          debug: false,
          numThreads: 2,
          provider: 'cpu',
        ),
        maxNumSentences: 1,
      );

      _tts = sherpa.OfflineTts(config);
      _initialized = true;
      debugPrint('PiperTtsService: initialized with Indian accent model');
    } catch (e) {
      debugPrint('PiperTtsService: init failed: $e');
      _initialized = false;
    }
  }

  @override
  Future<void> speak(String text) async {
    if (!_initialized || _tts == null) {
      debugPrint('PiperTtsService: not initialized, cannot speak');
      return;
    }

    final sanitized = stripEmojis(text);
    if (sanitized.trim().isEmpty) return;

    _speaking = true;
    try {
      // Duck background music
      unawaited(AudioService.maybeInstance?.duckForSpeech());

      final audio = _tts!.generate(
        text: sanitized,
        sid: 0,
        speed: 1.0,
      );

      if (audio.samples.isEmpty) {
        debugPrint('PiperTtsService: empty audio generated');
        return;
      }

      // Play the generated audio samples
      final completer = Completer<void>();
      await audio.play(onDone: () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('PiperTtsService: speak failed: $e');
    } finally {
      _speaking = false;
      unawaited(AudioService.maybeInstance?.unduckAfterSpeech());
      _doneController.add(null);
    }
  }

  @override
  Future<void> stop() async {
    _speaking = false;
    // sherpa-onnx doesn't have a mid-speech stop, audio will finish naturally
    unawaited(AudioService.maybeInstance?.unduckAfterSpeech());
    _doneController.add(null);
  }

  @override
  bool get isSpeaking => _speaking;

  void dispose() {
    _tts?.free();
    _doneController.close();
  }
}
