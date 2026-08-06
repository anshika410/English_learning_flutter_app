// Abstract STT + TTS interfaces and standard-package implementations.
// ella_app uses speech_to_text + flutter_tts (Flutter plugins with built-in
// native bindings). We do NOT reuse /frontend's MethodChannel-based services
// because ella_app has its own Android shell.

import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart'
    show SpeechRecognitionResult;
import 'package:flutter_tts/flutter_tts.dart';
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

// ── STT ─────────────────────────────────────────────────────────────────────

abstract class SttInterface {
  Future<void> initialize();
  Future<void> startListening({
    required void Function(String partial) onPartial,
    required void Function(String finalText) onFinal,
  });
  Future<void> stopListening();
  bool get isListening;
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

  // Child intent: true between startListening() and stopListening().
  bool _sessionActive = false;
  // Whether the OS recognizer is actively capturing right now.
  bool _recognizerRunning = false;

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
    // Idempotent: the first call triggers the OS mic-permission prompt via the
    // speech_to_text plugin; later calls are no-ops so we don't re-prompt.
    if (_ready) return;
    _ready = await _stt.initialize(
      onError: (error) {
        AnalyticsService.logSttError(
          error.errorMsg,
          error.permanent ? 'permanent' : 'transient',
        );
        // IMPORTANT: the Android plugin flags EVERY error as `permanent` —
        // including `error_no_match` / `error_speech_timeout`, which fire on an
        // ordinary silent pause. So we must NOT finalize (send) on the
        // permanent flag; doing so sent the turn on random pauses before the
        // child tapped Send. The statusListener restart already carries the
        // session through these transient pause errors.
        //
        // Only a genuine permission failure is fatal — end the session, and do
        // it WITHOUT sending a turn.
        if (error.errorMsg == 'error_permission') {
          AnalyticsService.logMicPermissionDenied();
          _abortSession();
        }
      },
    );
    if (!_ready) {
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
    _accumulated = '';
    _currentPartial = '';
    _onPartial = onPartial;
    _onFinal = onFinal;
    AnalyticsService.logSttStarted();

    _stt.statusListener = (status) {
      // The recognizer stopped (silence pause, segment cap, or our own stop).
      // While the child still wants to dictate, fold the last partial in and
      // restart so listening continues instead of ending the turn.
      if (status == 'notListening' || status == 'done') {
        _recognizerRunning = false;
        if (_sessionActive) {
          _foldPartial();
          _scheduleRestart();
        }
      }
    };

    await _startRecognizer();
  }

  Future<void> _startRecognizer() async {
    if (!_sessionActive || _recognizerRunning) return;
    _recognizerRunning = true;
    _currentPartial = '';
    try {
      await _stt.listen(
        onResult: _handleResult,
        listenOptions: stt.SpeechListenOptions(
          // Each segment caps at 60s; a longer pauseFor tolerates natural
          // thinking pauses before the recognizer ends the segment (we restart
          // regardless, so this only trims restart churn).
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 6),
          partialResults: true,
          cancelOnError: false,
          localeId: 'en_US',
        ),
      );
    } catch (_) {
      _recognizerRunning = false;
      // Retry shortly; a hard failure is caught by the permanent-error path.
      _scheduleRestart();
    }
  }

  /// Handles both partial and final results from ONE recognizer run.
  ///
  /// We deliberately do NOT commit on `finalResult` here — a final is just the
  /// best version of the current live phrase. Committing happens in exactly one
  /// place, [_foldPartial] (on the statusListener's `done`, on restart, and on
  /// stop), so a segment can never be dropped by an empty final or double-added
  /// by a final+done race.
  void _handleResult(SpeechRecognitionResult r) {
    // Ignore anything arriving while no run is active (e.g. a late final from
    // the previous run landing during the restart gap) — it would otherwise be
    // re-committed on top of the already-folded text.
    if (!_sessionActive || !_recognizerRunning) return;
    final words = r.recognizedWords.trim();
    // An empty result must never wipe the live phrase before it's committed.
    if (words.isEmpty) return;

    // Android can start a NEW phrase mid-run: recognizedWords stops extending
    // (and isn't an extension/revision of) the current phrase. Commit the old
    // phrase before the new one overwrites it. A bidirectional prefix check
    // treats plain growth ("I" → "I am") and shrinking revisions ("helloo" →
    // "hello") as the same phrase, so only a real reset triggers a commit.
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

  /// Commits the live phrase into the accumulated transcript. Idempotent — it
  /// clears [_currentPartial], so the final/done ordering can't double-commit.
  void _foldPartial() {
    final p = _currentPartial.trim();
    if (p.isEmpty) return;
    _accumulated = _accumulated.isEmpty ? p : '$_accumulated $p';
    _currentPartial = '';
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    if (!_sessionActive) return;
    // Small delay so the previous recognizer fully tears down before we start
    // the next one (starting too eagerly can fail on Android).
    _restartTimer = Timer(const Duration(milliseconds: 250), () {
      if (_sessionActive && !_recognizerRunning) _startRecognizer();
    });
  }

  /// Ends the session and delivers the committed transcript exactly once. Only
  /// an explicit stop (the child's Send tap) reaches this.
  void _finishSession() {
    if (!_sessionActive && _onFinal == null) return;
    _sessionActive = false;
    _recognizerRunning = false;
    _restartTimer?.cancel();
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

  /// Ends the session on a fatal error (e.g. permission denied) WITHOUT sending
  /// a turn. Delivers an empty final so the caller just returns to idle — a
  /// recognition error must never be mistaken for the child's Send.
  void _abortSession() {
    if (!_sessionActive && _onFinal == null) return;
    _sessionActive = false;
    _recognizerRunning = false;
    _restartTimer?.cancel();
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
    if (!_sessionActive) return;
    _sessionActive = false;
    _restartTimer?.cancel();
    try {
      await _stt.stop();
    } catch (_) {}
    _recognizerRunning = false;
    // Explicit stop == the child's Send: finalize the accumulated turn now.
    _finishSession();
  }

  @override
  bool get isListening => _sessionActive;
}

// ── TTS ─────────────────────────────────────────────────────────────────────

abstract class TtsInterface {
  Future<void> initialize();
  Future<void> speak(String text);
  Future<void> stop();
  bool get isSpeaking;
}

class FlutterTtsService implements TtsInterface {
  final _tts = FlutterTts();
  bool _speaking = false;

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
    _tts.setCompletionHandler(() => _speaking = false);
  }

  /// Strips emojis and markdown before handing text to the TTS engine.
  static String _sanitizeForTts(String text) {
    return stripEmojis(
      text
          .replaceAll(RegExp(r'\*\*(.+?)\*\*', dotAll: true), r'$1')
          .replaceAll(RegExp(r'\*(.+?)\*', dotAll: true), r'$1')
          .replaceAll(RegExp(r'__(.+?)__', dotAll: true), r'$1')
          .replaceAll(RegExp(r'_(.+?)_', dotAll: true), r'$1')
          .replaceAll(RegExp(r'`(.+?)`', dotAll: true), r'$1')
          .replaceAll(RegExp(r'~~(.+?)~~', dotAll: true), r'$1')
          .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)', dotAll: true), r'$1')
          .replaceAll(RegExp(r'^#+\s+', multiLine: true), '')
          .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), ''),
    );
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
  }

  @override
  bool get isSpeaking => _speaking;
}
