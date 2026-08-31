import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages downloading and caching the Piper TTS model files on-device.
/// Model is downloaded once from HuggingFace and stored in app documents dir.
class PiperModelService {
  static const _modelDownloadedKey = 'piper_model_downloaded';

  // NavGurukul Indian accent model on HuggingFace
  static const _modelOnnxUrl =
      'https://huggingface.co/navgurukul-ai/Indian_accent_60/resolve/main/model.onnx';
  static const _modelJsonUrl =
      'https://huggingface.co/navgurukul-ai/Indian_accent_60/resolve/main/model.json';

  static PiperModelService? _instance;
  static PiperModelService get instance => _instance ??= PiperModelService._();
  PiperModelService._();

  String? _modelOnnxPath;
  String? _modelJsonPath;

  bool get isReady => _modelOnnxPath != null && _modelJsonPath != null;

  String? get modelOnnxPath => _modelOnnxPath;
  String? get modelJsonPath => _modelJsonPath;

  /// Returns model paths if already downloaded, null otherwise.
  Future<bool> checkIfDownloaded() async {
    final dir = await getApplicationDocumentsDirectory();
    final onnxFile = File('${dir.path}/piper_model.onnx');
    final jsonFile = File('${dir.path}/piper_model.json');

    if (await onnxFile.exists() && await jsonFile.exists()) {
      _modelOnnxPath = onnxFile.path;
      _modelJsonPath = jsonFile.path;
      return true;
    }
    return false;
  }

  /// Downloads the model files. Shows progress via [onProgress] (0.0 to 1.0).
  Future<bool> downloadModel({
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final onnxPath = '${dir.path}/piper_model.onnx';
      final jsonPath = '${dir.path}/piper_model.json';

      // Download model.json first (small, ~5KB)
      onProgress?.call(0.0, 'Downloading voice model...');
      await _downloadFile(_modelJsonUrl, jsonPath, (p) {
        onProgress?.call(p * 0.1, 'Downloading voice model...');
      });

      // Download model.onnx (large, ~64MB)
      await _downloadFile(_modelOnnxUrl, onnxPath, (p) {
        onProgress?.call(0.1 + p * 0.9, 'Downloading voice model...');
      });

      _modelOnnxPath = onnxPath;
      _modelJsonPath = jsonPath;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_modelDownloadedKey, true);

      onProgress?.call(1.0, 'Voice model ready!');
      return true;
    } catch (e) {
      debugPrint('PiperModelService: download failed: $e');
      return false;
    }
  }

  Future<void> _downloadFile(
    String url,
    String savePath,
    void Function(double) onProgress,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} for $url');
      }

      final total = response.contentLength ?? 0;
      var received = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress(received / total);
        }
      }
      await sink.close();
    } finally {
      client.close();
    }
  }

  /// Deletes cached model files (e.g. to free space).
  Future<void> clearModel() async {
    final dir = await getApplicationDocumentsDirectory();
    final onnxFile = File('${dir.path}/piper_model.onnx');
    final jsonFile = File('${dir.path}/piper_model.json');
    if (await onnxFile.exists()) await onnxFile.delete();
    if (await jsonFile.exists()) await jsonFile.delete();
    _modelOnnxPath = null;
    _modelJsonPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modelDownloadedKey);
  }
}
