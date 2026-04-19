import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'tts_service.dart';

/// OpenAI TTS engine for web — calls /v1/audio/speech and plays via Web Audio API.
/// Falls back gracefully if API key is missing.
class OpenAiTtsEngine extends TtsEngine {
  bool _isSpeaking = false;
  web.HTMLAudioElement? _audio;

  @override
  String get name => 'OpenAI TTS';

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<bool> get isAvailable async {
    if (!kIsWeb) return false;
    final key = dotenv.maybeGet('OPENAI_API_KEY') ?? '';
    return key.isNotEmpty;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    if (!kIsWeb) return;
    final apiKey = dotenv.maybeGet('OPENAI_API_KEY') ?? '';
    if (apiKey.isEmpty) {
      debugPrint('OpenAI TTS: no API key, skipping');
      return;
    }

    await stop();
    _isSpeaking = true;

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: '{"model":"tts-1","input":${_jsonString(text)},"voice":"nova","response_format":"mp3"}',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('OpenAI TTS: error ${response.statusCode}');
        _isSpeaking = false;
        return;
      }

      // Convert bytes to blob URL and play
      final bytes = response.bodyBytes;
      final jsArray = bytes.toJS;
      final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: 'audio/mpeg'));
      final url = web.URL.createObjectURL(blob);

      final audio = web.HTMLAudioElement();
      _audio = audio;
      audio.src = url;

      final completer = Completer<void>();
      audio.onended = (web.Event _) {
        web.URL.revokeObjectURL(url);
        _isSpeaking = false;
        if (!completer.isCompleted) completer.complete();
      }.toJS;
      audio.onerror = (web.Event _) {
        web.URL.revokeObjectURL(url);
        _isSpeaking = false;
        if (!completer.isCompleted) completer.complete();
      }.toJS;

      audio.play();
      await completer.future;
    } catch (e) {
      debugPrint('OpenAI TTS: $e');
      _isSpeaking = false;
    }
  }

  @override
  Future<void> stop() async {
    _audio?.pause();
    _audio = null;
    _isSpeaking = false;
  }

  @override
  void dispose() => stop();

  String _jsonString(String text) {
    final escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
    return '"$escaped"';
  }
}
