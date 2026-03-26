/// Base interface for all TTS engines.
abstract class TtsEngine {
  String get name;
  bool get isSpeaking;
  Future<void> initialize();
  Future<bool> get isAvailable;
  Future<void> speak(String text);
  Future<void> stop();
  void dispose();
}

/// Represents a Piper voice/accent model.
class PiperVoice {
  final String id;
  final String label; // e.g. "British English", "Indian English"
  final String modelPath; // path to .onnx file
  final String configPath; // path to .onnx.json file

  const PiperVoice({
    required this.id,
    required this.label,
    required this.modelPath,
    required this.configPath,
  });
}
