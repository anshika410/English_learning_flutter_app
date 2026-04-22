import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_service.dart';

class SystemTtsEngine extends TtsEngine {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  String get name => 'System TTS';

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<bool> get isAvailable async => true; // always available

  @override
  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    // Force a US English voice — avoid Indian accent on Indian devices
    try {
      final voices = await _tts.getVoices as List?;
      if (voices != null) {
        // Prefer en-us-x-* (Google US voices) or any en-US voice
        final usVoices = voices
            .cast<Map>()
            .where((v) {
              final locale = (v['locale'] as String? ?? '').toLowerCase();
              final name = (v['name'] as String? ?? '').toLowerCase();
              return locale == 'en-us' &&
                  !name.contains('in') &&
                  !name.contains('ind');
            })
            .toList();

        if (usVoices.isNotEmpty) {
          // Prefer "en-us-x-sfg" (female) or first available US voice
          final preferred = usVoices.firstWhere(
            (v) {
              final n = (v['name'] as String? ?? '').toLowerCase();
              return n.contains('sfg') || n.contains('tpc') || n.contains('iob');
            },
            orElse: () => usVoices.first,
          );
          await _tts.setVoice({
            'name': preferred['name'] as String,
            'locale': preferred['locale'] as String,
          });
          debugPrint('TTS: Using voice ${preferred['name']} (${preferred['locale']})');
        } else {
          debugPrint('TTS: No US voice found, using default en-US');
        }
      }
    } catch (_) {
      // Voice selection is best-effort — fall back to language setting
    }

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) => _isSpeaking = false);
  }

  @override
  Future<void> speak(String text) async {
    if (_isSpeaking) await stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  @override
  void dispose() {
    _tts.stop();
  }
}
