import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'audio_service.dart';
import 'stt_tts_service.dart';
import 'analytics_service.dart';

class TtsProgressEvent {
  final int start;
  final int end;
  const TtsProgressEvent(this.start, this.end);
}

/// Native Android TTS with karaoke word-highlight via onRangeStart.
/// Falls back gracefully if the channel isn't available (e.g., on web/iOS).
class NativeTtsService with WidgetsBindingObserver implements TtsInterface {
  static const _channel = MethodChannel('ella/native_tts');
  static NativeTtsService? instance;

  bool _speaking = false;
  bool _pendingSpeak = false; // true while speak() is awaiting the channel invoke
  int _highlightStart = 0;
  int _highlightEnd = 0;
  
  int _currentTextLength = 0;
  Timer? _fallbackDoneTimer;

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
    instance = this;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      stop();
    }
  }

  void dispose() {
    _fallbackDoneTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (instance == this) {
      instance = null;
    }
  }

  @override
  Future<void> initialize() async {
    // Native method call handler registered in constructor.
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onTtsStart':
        _fallbackDoneTimer?.cancel();
        _speaking = true;
        _highlightStart = 0;
        _highlightEnd = 0;
        AnalyticsService.logTtsStarted();
        // Dim the background music (and mute SFX) under Zoe's voice.
        unawaited(AudioService.maybeInstance?.duckForSpeech());
        break;
      case 'onTtsDone':
        _fallbackDoneTimer?.cancel();
        _speaking = false;
        _highlightStart = 0;
        _highlightEnd = 0;
        AnalyticsService.logTtsCompleted();
        // Restore music BEFORE emitting done: doneStream listeners play SFX
        // (e.g. the turn chime) and playSfx is a no-op while ducked.
        unawaited(AudioService.maybeInstance?.unduckAfterSpeech());
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
        if (end >= _currentTextLength) {
          _fallbackDoneTimer?.cancel();
          _fallbackDoneTimer = Timer(const Duration(milliseconds: 600), () {
            if (_speaking) {
              _speaking = false;
              _highlightStart = 0;
              _highlightEnd = 0;
              AnalyticsService.logTtsCompleted();
              AudioService.maybeInstance?.unduckAfterSpeech();
              _doneController.add(null);
              onDone?.call();
            }
          });
        }
        break;
    }
  }

  @override
  Future<void> speak(String text) async {
    final sanitized = stripEmojis(text);
    if (sanitized.trim().isEmpty) return;
    _fallbackDoneTimer?.cancel();
    _currentTextLength = sanitized.length;
    _speaking = true;
    _pendingSpeak = true; // guard against stop() completing our completer
    try {
      final completer = Completer<void>();
      late StreamSubscription sub;
      sub = _doneController.stream.listen((_) {
        sub.cancel();
        if (!completer.isCompleted) completer.complete();
      });
      await _channel.invokeMethod('speak', {'text': sanitized});
      _pendingSpeak = false;
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () { sub.cancel(); },
      );
    } catch (e) {
      _speaking = false;
      _pendingSpeak = false;
      AnalyticsService.logTtsFailed(e.toString());
    } finally {
      // Normally onTtsDone already unducked (this is then a no-op); this
      // covers the timeout/error paths so music and SFX never stay ducked.
      await AudioService.maybeInstance?.unduckAfterSpeech();
    }
  }

  @override
  Future<void> stop() async {
    _fallbackDoneTimer?.cancel();
    final wasSpeaking = _speaking;
    _speaking = false;
    _highlightStart = 0;
    _highlightEnd = 0;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
    unawaited(AudioService.maybeInstance?.unduckAfterSpeech());
    // Only emit doneStream if we're NOT in the middle of queuing a new speak()
    // call. If _pendingSpeak is true, speak() hasn't started yet and emitting
    // here would prematurely resolve its completer, causing double-speak.
    if (wasSpeaking && !_pendingSpeak) {
      _doneController.add(null);
    }
  }

  @override
  bool get isSpeaking => _speaking;
  int get highlightStart => _highlightStart;
  int get highlightEnd => _highlightEnd;
}
