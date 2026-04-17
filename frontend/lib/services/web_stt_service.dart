import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Web STT service using the browser's Web Speech API via speech_to_text.
/// Used as a fallback on web platform where native Android STT is unavailable.
class WebSttService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _isListening = false;

  void Function(bool isRecognizing)? onRecognizingChanged;

  bool get isListening => _isListening;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize(
      onError: (error) => debugPrint('WebSTT error: $error'),
      onStatus: (status) {
        debugPrint('WebSTT status: $status');
        final isActive = status == 'listening';
        onRecognizingChanged?.call(isActive);
      },
    );
    return _initialized;
  }

  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    int silenceMs = 8000,
    int possibleSilenceMs = 5000,
    int minSpeechMs = 1500,
    String locale = 'en-US',
  }) async {
    if (!kIsWeb) return false;

    final ready = await _ensureInitialized();
    if (!ready) {
      debugPrint('WebSTT: not available in this browser');
      return false;
    }

    if (_isListening) await stopListening();

    _isListening = true;
    onRecognizingChanged?.call(true);

    _stt.listen(
      onResult: (result) {
        final text = result.recognizedWords;
        final isFinal = result.finalResult;
        debugPrint('WebSTT result: isFinal=$isFinal text="$text"');
        onResult(text, isFinal);
        if (isFinal) {
          _isListening = false;
          onRecognizingChanged?.call(false);
        }
      },
      listenFor: Duration(milliseconds: silenceMs),
      pauseFor: Duration(milliseconds: possibleSilenceMs),
      localeId: locale,
      cancelOnError: false,
      partialResults: true,
    );

    return true;
  }

  Future<String> stopListening() async {
    _isListening = false;
    onRecognizingChanged?.call(false);
    final lastWords = _stt.lastRecognizedWords;
    await _stt.stop();
    return lastWords;
  }

  void dispose() {
    _stt.cancel();
    onRecognizingChanged = null;
  }
}
