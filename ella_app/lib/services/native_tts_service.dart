import 'dart:async';
import 'package:flutter/services.dart';
import 'stt_tts_service.dart';

class TtsProgressEvent {
  final int start;
  final int end;
  const TtsProgressEvent(this.start, this.end);
}

/// Native Android TTS with karaoke word-highlight via onRangeStart.
/// Falls back gracefully if the channel isn't available (e.g., on web/iOS).
class NativeTtsService implements TtsInterface {
  static const _channel = MethodChannel('ella/native_tts');

  bool _speaking = false;
  int _highlightStart = 0;
  int _highlightEnd = 0;

  final _progressController = StreamController<TtsProgressEvent>.broadcast();
  Stream<TtsProgressEvent> get progressStream => _progressController.stream;

  final _doneController = StreamController<void>.broadcast();
  Stream<void> get doneStream => _doneController.stream;

  /// Callback fired when TTS highlights a new character range.
  void Function(int start, int end)? onRangeStart;

  /// Callback fired when TTS finishes speaking.
  void Function()? onDone;

  NativeTtsService() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  @override
  Future<void> initialize() async {
    // Native method call handler registered in constructor.
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onTtsStart':
        _speaking = true;
        _highlightStart = 0;
        _highlightEnd = 0;
        break;
      case 'onTtsDone':
        _speaking = false;
        _highlightStart = 0;
        _highlightEnd = 0;
        _doneController.add(null);
        onDone?.call();
        break;
      case 'onRangeStart':
        final start = call.arguments['start'] as int;
        final end = call.arguments['end'] as int;
        _highlightStart = start;
        _highlightEnd = end;
        _progressController.add(TtsProgressEvent(start, end));
        onRangeStart?.call(start, end);
        break;
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _speaking = true;
    try {
      await _channel.invokeMethod('speak', {'text': text});
    } catch (e) {
      _speaking = false;
    }
  }

  Future<void> stop() async {
    _speaking = false;
    _highlightStart = 0;
    _highlightEnd = 0;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  bool get isSpeaking => _speaking;
  int get highlightStart => _highlightStart;
  int get highlightEnd => _highlightEnd;
}
