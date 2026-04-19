import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'tts_service.dart';

/// Web TTS engine — uses the browser's native SpeechSynthesis API directly.
class WebTtsEngine extends TtsEngine {
  bool _isSpeaking = false;
  Completer<void>? _speakCompleter;

  @override
  String get name => 'Web Speech API';

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<bool> get isAvailable async {
    if (!kIsWeb) return false;
    return web.window.speechSynthesis != null;
  }

  @override
  Future<void> initialize() async {
    if (!kIsWeb) return;
    final synth = web.window.speechSynthesis;
    if (synth == null) return;
    synth.getVoices();
    debugPrint('WebTTS: SpeechSynthesis initialized');
  }

  @override
  Future<void> speak(String text) async {
    if (!kIsWeb) return;
    final synth = web.window.speechSynthesis;
    if (synth == null) return;

    if (_isSpeaking) await stop();

    final voices = synth.getVoices();
    if (voices.length == 0) await _waitForVoices(synth);

    final completer = Completer<void>();
    _speakCompleter = completer;
    _isSpeaking = true;

    final utterance = web.SpeechSynthesisUtterance(text);
    utterance.lang = 'en-US';
    utterance.rate = 0.9;
    utterance.pitch = 1.0;
    utterance.volume = 1.0;

    final allVoices = synth.getVoices();
    web.SpeechSynthesisVoice? preferred;
    for (var i = 0; i < allVoices.length; i++) {
      final v = allVoices[i];
      if (v.lang.startsWith('en')) {
        preferred = v;
        if (v.lang == 'en-US') break;
      }
    }
    if (preferred != null) utterance.voice = preferred;

    utterance.onend = (web.SpeechSynthesisEvent _) {
      _isSpeaking = false;
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    utterance.onerror = (web.SpeechSynthesisErrorEvent event) {
      _isSpeaking = false;
      final errMsg = event.error;
      if (errMsg != 'interrupted' && errMsg != 'canceled') {
        debugPrint('WebTTS: error: $errMsg');
      }
      if (!completer.isCompleted) completer.complete();
    }.toJS;

    synth.speak(utterance);
    await completer.future;
  }

  @override
  Future<void> stop() async {
    if (!kIsWeb) return;
    final synth = web.window.speechSynthesis;
    synth?.cancel();
    _isSpeaking = false;
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
  }

  @override
  void dispose() => stop();

  Future<void> _waitForVoices(web.SpeechSynthesis synth) async {
    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (synth.getVoices().length > 0) return;
    }
  }
}
