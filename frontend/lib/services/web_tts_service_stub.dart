import 'tts_service.dart';

/// Stub for non-web platforms — WebTtsEngine is never used on Android/iOS.
class WebTtsEngine extends TtsEngine {
  @override
  String get name => 'Web Speech API (stub)';

  @override
  bool get isSpeaking => false;

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
