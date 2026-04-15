import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SttService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => debugPrint('STT error: ${error.errorMsg}'),
      onStatus: (status) => debugPrint('STT status: $status'),
    );
    debugPrint('STT initialized: $_isInitialized');
    return _isInitialized;
  }

  Future<bool> startListening({
    required void Function(SpeechRecognitionResult) onResult,
    required void Function() onDone,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        debugPrint('STT: Failed to initialize');
        return false;
      }
    }

    await _speech.listen(
      onResult: onResult,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(minutes: 5),
      localeId: 'en',
      onSoundLevelChange: null,
      listenOptions: SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
        autoPunctuation: true,
        listenMode: ListenMode.dictation,
      ),
    );

    // speech_to_text calls onDone when listening stops naturally
    _speech.statusListener = (status) {
      debugPrint('STT status: $status');
      if (status == 'done' || status == 'notListening') {
        onDone();
      }
    };

    return true;
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  void dispose() {
    _speech.cancel();
  }
}
