import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Continuous STT — auto-restarts the system speech recognizer when it stops,
/// accumulating text across multiple listening sessions.
class ContinuousSttService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _accumulatedText = '';
  String _currentPartial = '';
  Timer? _restartTimer;
  void Function(String text, bool isFinal)? _onResult;

  bool get isListening => _isListening;

  String get displayText {
    if (_accumulatedText.isEmpty) return _currentPartial;
    if (_currentPartial.isEmpty) return _accumulatedText;
    return '$_accumulatedText $_currentPartial';
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) {
        debugPrint('ContinuousSTT error: ${error.errorMsg}');
        _scheduleRestart();
      },
      onStatus: (status) {
        debugPrint('ContinuousSTT status: $status');
        if (status == 'done' && _isListening) {
          _scheduleRestart();
        }
      },
    );
    debugPrint('ContinuousSTT initialized: $_isInitialized');
    return _isInitialized;
  }

  Future<bool> startListening({
    required void Function(String fullText, bool isFinal) onResult,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    _accumulatedText = '';
    _currentPartial = '';
    _isListening = true;
    _onResult = onResult;

    _startSession();
    return true;
  }

  void _startSession() {
    if (!_isListening || !_isInitialized) return;
    debugPrint('ContinuousSTT: starting session...');

    _speech.listen(
      onResult: _handleResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en',
      listenOptions: SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
        autoPunctuation: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      final words = result.recognizedWords.trim();
      if (words.isNotEmpty) {
        _accumulatedText +=
            (_accumulatedText.isEmpty ? '' : ' ') + words;
        _currentPartial = '';
        _onResult?.call(_accumulatedText, false);
      }
    } else {
      _currentPartial = result.recognizedWords;
      _onResult?.call(displayText, false);
    }
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    if (!_isListening) return;
    _restartTimer = Timer(const Duration(milliseconds: 500), () {
      if (_isListening && _isInitialized) {
        debugPrint('ContinuousSTT: auto-restarting...');
        _startSession();
      }
    });
  }

  Future<String> stopListening() async {
    _isListening = false;
    _restartTimer?.cancel();
    await _speech.stop();
    // Include any partial text
    final result = displayText.trim();
    debugPrint('ContinuousSTT: stopped, result: "$result"');
    _accumulatedText = '';
    _currentPartial = '';
    _onResult = null;
    return result;
  }

  void dispose() {
    _isListening = false;
    _restartTimer?.cancel();
    _speech.cancel();
  }
}
