import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Continuous STT — auto-restarts the system speech recognizer when it stops,
/// accumulating text across multiple listening sessions.
class ContinuousSttService {
  static const _audioControl = MethodChannel('audio_control');

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isRecognizing = false; // true only when recognizer is actively running
  String _accumulatedText = '';
  String _currentPartial = '';
  Timer? _restartTimer;
  void Function(String text, bool isFinal)? _onResult;
  void Function(bool isRecognizing)? onRecognizingChanged;

  bool get isListening => _isListening;
  bool get isRecognizing => _isRecognizing;

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
        _setRecognizing(false);
        // Auto-restart disabled — user taps mic to speak again
        // _scheduleRestart();
      },
      onStatus: (status) {
        debugPrint('ContinuousSTT status: $status');
        if (status == 'listening') {
          _setRecognizing(true);
        } else if (status == 'done' || status == 'notListening') {
          _setRecognizing(false);
          // Auto-restart disabled — user taps mic to speak again
          // if (_isListening) _scheduleRestart();
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

    await _muteBeep();
    _startSession();
    return true;
  }

  void _startSession() {
    if (!_isListening || !_isInitialized) return;
    debugPrint('ContinuousSTT: starting session...');
    _setRecognizing(true);
    _speech.listen(
      onResult: _handleResult,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 10),
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
    // 1.5s delay — gives time for audio to settle before restart beep
    _restartTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (_isListening && _isInitialized) {
        debugPrint('ContinuousSTT: auto-restarting...');
        await _muteBeep();
        _startSession();
      }
    });
  }

  Future<void> _muteBeep() async {
    // Muting disabled — no auto-restart loop so no beep to suppress
    // if (!kIsWeb) {
    //   try {
    //     await _audioControl.invokeMethod('muteBeepStream');
    //     Future.delayed(const Duration(milliseconds: 800), () {
    //       _audioControl.invokeMethod('unmuteBeepStream').catchError((_) {});
    //     });
    //   } catch (_) {}
    // }
  }

  void _setRecognizing(bool value) {
    if (_isRecognizing == value) return;
    _isRecognizing = value;
    onRecognizingChanged?.call(value);
  }

  Future<String> stopListening() async {
    _isListening = false;
    _setRecognizing(false);
    _restartTimer?.cancel();
    await _speech.stop();
    // try {
    //   await _audioControl.invokeMethod('unmuteBeepStream');
    // } catch (_) {}
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
    // _audioControl.invokeMethod('unmuteBeepStream').catchError((_) {});
  }
}
