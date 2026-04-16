import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// On-device Whisper STT using whisper.cpp via platform channel.
/// Records audio natively, runs GGML inference locally, returns transcript.
class WhisperSttService {
  static const _channel = MethodChannel('whisper_recorder');
  bool _isRecording = false;
  bool _modelLoaded = false;

  bool get isRecording => _isRecording;
  bool get isAvailable => _modelLoaded;

  Future<bool> initialize() async {
    try {
      // Copy model from assets to local storage
      final modelPath = await _ensureModel();
      if (modelPath == null) return false;

      // Init native whisper engine
      _modelLoaded =
          await _channel.invokeMethod<bool>('initModel', {
            'modelPath': modelPath,
          }) ?? false;

      debugPrint('Whisper STT: Model loaded: $_modelLoaded');
      return _modelLoaded;
    } catch (e) {
      debugPrint('Whisper STT: Init failed: $e');
      return false;
    }
  }

  Future<String?> _ensureModel() async {
    final appDir = await getApplicationSupportDirectory();
    final modelFile = File(
      p.join(appDir.path, 'whisper', 'ggml-tiny.en.bin'),
    );

    if (!await modelFile.exists()) {
      try {
        debugPrint('Whisper STT: Copying model to local storage...');
        await modelFile.parent.create(recursive: true);
        final data = await rootBundle.load(
          'assets/whisper/ggml-tiny.en.bin',
        );
        await modelFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        debugPrint(
          'Whisper STT: Model copied (${modelFile.lengthSync()} bytes)',
        );
      } catch (e) {
        debugPrint('Whisper STT: Failed to copy model: $e');
        return null;
      }
    }

    return modelFile.path;
  }

  Future<bool> startRecording() async {
    if (_isRecording) return false;
    if (!_modelLoaded) {
      debugPrint('Whisper STT: Model not loaded, attempting init...');
      await initialize();
      if (!_modelLoaded) {
        debugPrint('Whisper STT: Model still not loaded after retry');
        return false;
      }
    }

    try {
      final started =
          await _channel.invokeMethod<bool>('startRecording') ?? false;
      _isRecording = started;
      debugPrint('Whisper STT: Recording started: $started');
      return started;
    } catch (e) {
      debugPrint('Whisper STT: Start failed: $e');
      return false;
    }
  }

  Future<String?> stopAndTranscribe() async {
    if (!_isRecording) return null;
    _isRecording = false;

    try {
      final transcript =
          await _channel.invokeMethod<String>('stopRecording');
      debugPrint('Whisper STT: Transcript: "$transcript"');
      return transcript?.trim();
    } catch (e) {
      debugPrint('Whisper STT: Transcription failed: $e');
      return null;
    }
  }

  Future<void> cancel() async {
    if (_isRecording) {
      try {
        await _channel.invokeMethod('stopRecording');
      } catch (_) {}
      _isRecording = false;
    }
  }

  void dispose() {
    cancel();
  }
}
