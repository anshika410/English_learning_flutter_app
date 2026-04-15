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
