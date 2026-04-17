import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Native Android STT service using direct SpeechRecognizer API.
/// Uses speech_to_text only for permission request, then uses
/// native channel with silence tuning extras.
class NativeSttService {
  static const _channel = MethodChannel('speech_handler');
  final SpeechToText _permissionHelper = SpeechToText();
  bool _permissionGranted = false;

  bool _isListening = false;
  bool _isRecognizing = false;
  String _accumulatedText = '';
  String _currentPartial = '';

  void Function(String text, bool isFinal)? _onResult;
  void Function(bool isRecognizing)? onRecognizingChanged;

  bool get isListening => _isListening;
  bool get isRecognizing => _isRecognizing;

  String get displayText {
    if (_accumulatedText.isEmpty) return _currentPartial;
    if (_currentPartial.isEmpty) return _accumulatedText;
    return '$_accumulatedText $_currentPartial';
  }

  NativeSttService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onStatus':
        final status = call.arguments as String;
        debugPrint('NativeSTT status: $status');
        if (status == 'listening' || status == 'speaking') {
          _setRecognizing(true);
        } else if (status == 'notListening' || status == 'done') {
          _setRecognizing(false);
        }
        break;

      case 'onResult':
        final args = call.arguments as Map;
        final text = args['text'] as String? ?? '';
        final isFinal = args['isFinal'] as bool? ?? false;
        if (isFinal) {
          if (text.isNotEmpty) {
            _accumulatedText += (_accumulatedText.isEmpty ? '' : ' ') + text;
            _currentPartial = '';
          }
          _isListening = false;
          _setRecognizing(false);
          final result = _accumulatedText.trim();
          _accumulatedText = '';
          _currentPartial = '';
          _onResult?.call(result, true);
          _onResult = null;
        } else {
          _currentPartial = text;
          _onResult?.call(displayText, false);
        }
        break;

      case 'onError':
        final error = call.arguments as String;
        debugPrint('NativeSTT error: $error');
        _setRecognizing(false);
        break;
    }
  }

  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    int silenceMs = 8000,
    int possibleSilenceMs = 5000,
    int minSpeechMs = 1500,
    String locale = 'en-US',
  }) async {
    if (kIsWeb) return false;

    // Ensure mic permission is granted via speech_to_text
    if (!_permissionGranted) {
      _permissionGranted = await _permissionHelper.initialize();
      if (!_permissionGranted) {
        debugPrint('NativeSTT: permission denied');
        return false;
      }
    }

    _accumulatedText = '';
    _currentPartial = '';
    _isListening = true;
    _onResult = onResult;

    try {
      await _channel.invokeMethod('startListening', {
        'silenceMs': silenceMs,
        'possibleSilenceMs': possibleSilenceMs,
        'minSpeechMs': minSpeechMs,
        'locale': locale,
      });
      return true;
    } catch (e) {
      debugPrint('NativeSTT: startListening failed: $e');
      _isListening = false;
      return false;
    }
  }

  Future<String> stopListening() async {
    _isListening = false;
    _setRecognizing(false);
    try {
      await _channel.invokeMethod('stopListening');
    } catch (_) {}
    final result = displayText.trim();
    debugPrint('NativeSTT: stopped, result: "$result"');
    _accumulatedText = '';
    _currentPartial = '';
    _onResult = null;
    return result;
  }

  void _setRecognizing(bool value) {
    if (_isRecognizing == value) return;
    _isRecognizing = value;
    onRecognizingChanged?.call(value);
  }

  void dispose() {
    _isListening = false;
    _channel.invokeMethod('cancel').catchError((_) {});
    _channel.setMethodCallHandler(null);
  }
}
