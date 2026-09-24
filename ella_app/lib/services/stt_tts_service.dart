// Abstract STT + TTS interfaces and standard-package implementations.
// ella_app uses speech_to_text + flutter_tts (Flutter plugins with built-in
// native bindings). We do NOT reuse /frontend's MethodChannel-based services
// because ella_app has its own Android shell.

import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart'
    show SpeechRecognitionResult;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'analytics_service.dart';

// ── Shared emoji / non-speech unicode stripping ──────────────────────────────


/// Regex that matches all common emoji and non-speech unicode codepoints.
/// Shared by both TTS services and TypewriterText so offsets always align.
final _kEmojiRegex = RegExp(
  r'[\u{1F600}-\u{1F64F}'   // emoticons
  r'\u{1F300}-\u{1F5FF}'   // misc symbols & pictographs
  r'\u{1F680}-\u{1F6FF}'   // transport & map
  r'\u{1F700}-\u{1F77F}'   // alchemical symbols
  r'\u{1F780}-\u{1F7FF}'   // geometric shapes extended
  r'\u{1F800}-\u{1F8FF}'   // supplemental arrows
  r'\u{1F900}-\u{1F9FF}'   // supplemental symbols & pictographs
  r'\u{1FA00}-\u{1FA6F}'   // chess symbols
  r'\u{1FA70}-\u{1FAFF}'   // symbols & pictographs extended-A
  r'\u{2600}-\u{26FF}'     // misc symbols (☀️🌙⭐ etc)
  r'\u{2700}-\u{27BF}'     // dingbats
  r'\u{FE00}-\u{FE0F}'     // variation selectors
  r'\u{1F1E0}-\u{1F1FF}'  // flags
  r'\u{200D}]',            // zero-width joiner
  unicode: true,
);

/// Strips emojis and other non-speech unicode, then collapses double spaces.
/// Used by both TTS services before speaking and by TypewriterText before
/// rendering, so that karaoke character offsets always line up with displayed
/// text.
String stripEmojis(String text) {
  return text
      .replaceAll(_kEmojiRegex, '')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .trim();
}

String _unwrapMarkdownSyntax(String text, RegExp pattern) {
  return text.replaceAllMapped(pattern, (match) {
    final innerText = match.group(1) ?? '';
    final matchedText = match.group(0) ?? '';

    if (innerText.isNotEmpty && RegExp(r'^_+$').hasMatch(innerText)) {
      return matchedText;
    }

    return innerText;
  });
}

/// Strips markdown formatting and emojis for both TTS playback and UI display,
/// ensuring character indices and word boundaries match 1:1 across native TTS
/// engines and UI widgets.
String sanitizeTtsText(String text) {
  var sanitized = text;
  sanitized = _unwrapMarkdownSyntax(
    sanitized,
    RegExp(r'\*\*(.+?)\*\*', dotAll: true),
  );
  sanitized = _unwrapMarkdownSyntax(
    sanitized,
    RegExp(r'\*(.+?)\*', dotAll: true),
  );
  sanitized = _unwrapMarkdownSyntax(
    sanitized,
    RegExp(r'__(.+?)__', dotAll: true),
  );
  sanitized = _unwrapMarkdownSyntax(
    sanitized,
    RegExp(r'_(.+?)_', dotAll: true),
  );
  sanitized = _unwrapMarkdownSyntax(
    sanitized,
    RegExp(r'`(.+?)`', dotAll: true),
  );
  sanitized = _unwrapMarkdownSyntax(
    sanitized,
    RegExp(r'~~(.+?)~~', dotAll: true),
  );
  sanitized = _unwrapMarkdownSyntax(
    sanitized,
    RegExp(r'\[(.+?)\]\(.+?\)', dotAll: true),
  );

  return stripEmojis(
    sanitized
        .replaceAll(RegExp(r'^#+\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), ''),
  );
}


// ── STT ─────────────────────────────────────────────────────────────────────

abstract class SttInterface {
  Future<void> initialize();
  Future<void> startListening({
    required void Function(String partial) onPartial,
    required void Function(String finalText) onFinal,
  });
  Future<void> stopListening();
  bool get isListening;
  ValueNotifier<double> get speechLevel;
}

/// Continuous STT.
///
/// The Android [SpeechRecognizer] backing `speech_to_text` always ends a listen
/// after a short silence (or its own segment cap) and reports it as a *final*
/// result. Treating that final as "the child is done" made us send the turn on
/// every natural pause — before the child tapped Send. It also lost anything
/// spoken after the pause.
///
/// So we decouple two ideas:
///   * [_sessionActive] — the child *wants* to keep dictating (from
///     [startListening] until [stopListening]).
///   * [_recognizerRunning] — the OS recognizer is *currently* capturing audio.
///
/// A recognizer-level final only accumulates text and restarts the recognizer;
/// the turn is finalized (via [onFinal]) *only* when the caller explicitly
/// stops — i.e. the child taps Send / the mic button. This keeps one dictation
/// session alive across pauses and long utterances.
class SpeechToTextService implements SttInterface {
  final _stt = stt.SpeechToText();
  bool _ready = false;

  @override
  final ValueNotifier<double> speechLevel = ValueNotifier<double>(0.0);

  // Child intent: true between startListening() and stopListening().
  bool _sessionActive = false;
  // Whether stopListening() is currently shutting down and waiting for final words.
  bool _stopping = false;
  // Whether the OS recognizer is actively capturing right now.
  bool _recognizerRunning = false;

  Completer<void>? _finalResultCompleter;

  // Segments finalized by earlier recognizer runs in THIS session.
  String _accumulated = '';
  // Live (not-yet-final) words from the current recognizer run.
  String _currentPartial = '';

  void Function(String partial)? _onPartial;
  void Function(String finalText)? _onFinal;
  Timer? _restartTimer;

  /// Everything heard so far this session: committed segments plus the live
  /// partial.
  String get _displayText {
    if (_accumulated.isEmpty) return _currentPartial;
    if (_currentPartial.isEmpty) return _accumulated;
    return '$_accumulated $_currentPartial';
  }

  @override
  Future<void> initialize() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      _ready = false;
      return;
    }
    // Idempotent: the first call triggers the OS mic-permission prompt via the
    // speech_to_text plugin; later calls are no-ops so we don't re-prompt.
    if (_ready) return;
    try {
      _ready = await _stt.initialize(
        onError: (error) {
          AnalyticsService.logSttError(
            error.errorMsg,
            error.permanent ? 'permanent' : 'transient',
            isPermanent: error.permanent,
            stage: 'recognizer_error',
            accumulatedTextLength: _displayText.trim().length,
          );
          if (error.errorMsg == 'error_permission') {
            AnalyticsService.logMicPermissionDenied();
            _abortSession();
          }
        },
      );
      if (!_ready) {
        AnalyticsService.logSttError(
          'init_failed',
          'SpeechToText initialize returned false (recognizer unavailable or permission missing)',
          stage: 'initialize',
          isPermanent: true,
        );
        AnalyticsService.logMicPermissionDenied();
      }
    } catch (e, stackTrace) {
      _ready = false;
      AnalyticsService.logSttError(
        'init_exception',
        'Exception during SpeechToText initialization: $e',
        stage: 'initialize',
        stackTrace: stackTrace,
        isPermanent: true,
      );
      AnalyticsService.logMicPermissionDenied();
    }
  }

  @override
  Future<void> startListening({
    required void Function(String partial) onPartial,
    required void Function(String finalText) onFinal,
  }) async {
    if (!_ready || _sessionActive) return;
    _sessionActive = true;
    _stopping = false;
    _finalResultCompleter = null;
    _accumulated = '';
    _currentPartial = '';
    _onPartial = onPartial;
    _onFinal = onFinal;
    AnalyticsService.logSttStarted();

    _stt.statusListener = (status) {
      // The recognizer stopped (silence pause, segment cap, or our own stop).
      if (status == 'notListening' || status == 'done') {
        _recognizerRunning = false;
        speechLevel.value = 0.0;
        if (_stopping) {
          if (status == 'done') {
            if (_finalResultCompleter != null && !_finalResultCompleter!.isCompleted) {
              _finalResultCompleter!.complete();
            }
          }
        } else if (_sessionActive) {
          _foldPartial();
          _scheduleRestart();
        }
      }
    };

    await _startRecognizer();
  }

  Future<void> _startRecognizer() async {
    if (!_sessionActive || _stopping || _recognizerRunning) return;
    _recognizerRunning = true;
    _currentPartial = '';
    try {
      await _stt.listen(
        onResult: _handleResult,
        onSoundLevelChange: (level) {
          speechLevel.value = ((level + 2) / 12).clamp(0.0, 1.0);
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 6),
          partialResults: true,
          cancelOnError: false,
          localeId: 'en_US',
        ),
      );
    } catch (e, stackTrace) {
      _recognizerRunning = false;
      AnalyticsService.logSttError(
        'listen_exception',
        'Exception during _stt.listen(): $e',
        stage: 'start_recognizer',
        accumulatedTextLength: _displayText.trim().length,
        stackTrace: stackTrace,
      );
      if (!_stopping) {
        _scheduleRestart();
      }
    }
  }

  void _handleResult(SpeechRecognitionResult r) {
    if (!_sessionActive && !_stopping) return;
    final words = r.recognizedWords.trim();
    if (words.isNotEmpty) {
      final wl = words.toLowerCase();
      final pl = _currentPartial.toLowerCase();
      final samePhrase = _currentPartial.isEmpty || wl.contains(pl) || pl.contains(wl);
      if (!samePhrase) {
        _accumulated =
            _accumulated.isEmpty ? _currentPartial : '$_accumulated $_currentPartial';
        _currentPartial = '';
      }

      _currentPartial = words;
      _onPartial?.call(_displayText.trim());
    }

    if (r.finalResult) {
      if (_finalResultCompleter != null && !_finalResultCompleter!.isCompleted) {
        _finalResultCompleter!.complete();
      }
    }
  }

  void _foldPartial() {
    final p = _currentPartial.trim();
    if (p.isEmpty) return;
    _accumulated = _accumulated.isEmpty ? p : '$_accumulated $p';
    _currentPartial = '';
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    if (!_sessionActive || _stopping) return;
    _restartTimer = Timer(const Duration(milliseconds: 250), () {
      if (_sessionActive && !_stopping && !_recognizerRunning) _startRecognizer();
    });
  }

  void _finishSession() {
    _sessionActive = false;
    _stopping = false;
    _recognizerRunning = false;
    _finalResultCompleter = null;
    _restartTimer?.cancel();
    speechLevel.value = 0.0;
    _foldPartial();
    final finalText = _displayText.trim();
    final cb = _onFinal;
    _onFinal = null;
    _onPartial = null;
    _accumulated = '';
    _currentPartial = '';
    if (cb != null) {
      AnalyticsService.logSttSuccess();
      cb(finalText);
    }
  }

  void _abortSession() {
    _sessionActive = false;
    _stopping = false;
    _recognizerRunning = false;
    _finalResultCompleter = null;
    _restartTimer?.cancel();
    speechLevel.value = 0.0;
    final cb = _onFinal;
    _onFinal = null;
    _onPartial = null;
    _accumulated = '';
    _currentPartial = '';
    try {
      _stt.stop();
    } catch (_) {}
    cb?.call('');
  }

  @override
  Future<void> stopListening() async {
    if (!_sessionActive || _stopping) return;
    _stopping = true;
    _restartTimer?.cancel();
    speechLevel.value = 0.0;

    final completer = Completer<void>();
    _finalResultCompleter = completer;

    try {
      await _stt.stop();
    } catch (_) {}

    // Wait for the recognizer to deliver the final SpeechRecognitionResult or status=done
    try {
      await completer.future.timeout(
        const Duration(milliseconds: 1000),
        onTimeout: () {
          debugPrint('STT: timeout waiting for final result after stop, using latest partial');
        },
      );
    } catch (_) {}

    _finalResultCompleter = null;
    _recognizerRunning = false;
    _sessionActive = false;
    _stopping = false;
    _finishSession();
  }

  @override
  bool get isListening => _sessionActive;
}

class TtsProgressEvent {
  final int start;
  final int end;
  const TtsProgressEvent(this.start, this.end);
}

abstract class TtsInterface {
  Future<void> initialize();
  Future<void> speak(String text);
  Future<void> stop();
  bool get isSpeaking;
  Stream<TtsProgressEvent> get progressStream;
  Stream<void> get doneStream;
}

class FlutterTtsService implements TtsInterface {
  final _tts = FlutterTts();
  bool _speaking = false;

  final _progressController = StreamController<TtsProgressEvent>.broadcast();
  @override
  Stream<TtsProgressEvent> get progressStream => _progressController.stream;

  final _doneController = StreamController<void>.broadcast();
  @override
  Stream<void> get doneStream => _doneController.stream;

  @override
  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48); // slightly slower for children
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.1); // slightly higher pitch for Zoe
    // Make speak() await actual playback completion. Without this flutter_tts
    // returns as soon as the utterance is queued, so callers that `await speak`
    // (and the zoeSpeaking status that drives the open-mouth mascot) would end
    // the moment audio starts instead of when Zoe finishes talking.
    await _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() {
      _speaking = false;
      _doneController.add(null);
    });
    _tts.setProgressHandler((text, start, end, word) {
      _progressController.add(TtsProgressEvent(start, end));
    });
  }

  /// Strips emojis and markdown before handing text to the TTS engine.
  static String _sanitizeForTts(String text) {
    return sanitizeTtsText(text);
  }

  @override
  Future<void> speak(String text) async {
    final sanitized = _sanitizeForTts(text);
    if (sanitized.isEmpty) return;
    _speaking = true;
    await _tts.speak(sanitized);
  }

  @override
  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
    _doneController.add(null);
  }

  @override
  bool get isSpeaking => _speaking;
}
