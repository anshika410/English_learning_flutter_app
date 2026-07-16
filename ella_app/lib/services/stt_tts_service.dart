// Abstract STT + TTS interfaces and standard-package implementations.
// ella_app uses speech_to_text + flutter_tts (Flutter plugins with built-in
// native bindings). We do NOT reuse /frontend's MethodChannel-based services
// because ella_app has its own Android shell.

import 'package:speech_to_text/speech_to_text.dart' as stt;
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

class SpeechToTextService implements SttInterface {
  final _stt = stt.SpeechToText();
  bool _ready = false;
  bool _listening = false;

  // Track accumulated text segments during active session to prevent word disappearance on pauses
  String _sessionPrefix = '';
  String _lastWords = '';

  @override
  Future<void> initialize() async {
    // Idempotent: the first call triggers the OS mic-permission prompt via the
    // speech_to_text plugin; later calls are no-ops so we don't re-prompt.
    if (_ready) return;
    _ready = await _stt.initialize(
      onError: (error) {
        AnalyticsService.logSttError(error.errorMsg, error.permanent ? 'permanent' : 'transient');
      },
    );
  }

  @override
  Future<void> startListening({
    required void Function(String partial) onPartial,
    required void Function(String finalText) onFinal,
  }) async {
    if (!_ready || _listening) return;
    _listening = true;
    _sessionPrefix = '';
    _lastWords = '';

    _stt.statusListener = (status) {
      // Android SpeechRecognizer sometimes stops without firing finalResult.
      // Detect "notListening" or "done" status and fire onFinal with whatever
      // we have if we're still in listening state.
      if (status == 'notListening' || status == 'done') {
        if (_listening) {
          _listening = false;
          // The onResult with finalResult:true should follow shortly.
          // If it doesn't (Android bug), this ensures we don't get stuck.
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!_listening && _stt.lastRecognizedWords.isEmpty) {
              final finalVal = _sessionPrefix.isEmpty ? _lastWords : "$_sessionPrefix $_lastWords";
              onFinal(finalVal.trim());
            }
          });
        }
      }
    };
    await _stt.listen(
      onResult: (r) {
        final newWords = r.recognizedWords.trim();
        final newWordsLower = newWords.toLowerCase();
        final lastWordsLower = _lastWords.toLowerCase();

        // If the new phrase is completely different and doesn't contain the last phrase,
        // we commit the last phrase to the prefix.
        if (_lastWords.isNotEmpty && !newWordsLower.contains(lastWordsLower)) {
          _sessionPrefix = _sessionPrefix.isEmpty ? _lastWords : "$_sessionPrefix $_lastWords";
        }

        _lastWords = newWords;
        final fullTranscript = _sessionPrefix.isEmpty ? newWords : "$_sessionPrefix $newWords";

        if (r.finalResult) {
          _listening = false;
          onFinal(fullTranscript.trim());
        } else {
          onPartial(fullTranscript.trim());
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        localeId: 'en_US',
      ),
    );
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
    await _stt.stop();
  }

  @override
  bool get isListening => _listening && _stt.isListening;
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
