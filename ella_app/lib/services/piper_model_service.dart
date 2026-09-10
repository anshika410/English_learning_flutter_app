import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages downloading and caching the Piper TTS model files on-device.
///
/// Required files:
///   - model.onnx       — NavGurukul Indian accent VITS model (sherpa metadata patched in)
///   - tokens.txt       — phoneme→id map for the model
///   - espeak-ng-data/  — eSpeak-NG language data for Piper phonemization
class PiperModelService {
  static const _modelDownloadedKey = 'piper_model_downloaded_v2';

  // Patched ONNX + tokens served from ella.navgurukul.org (model has sherpa-onnx ONNX metadata)
  static const _modelOnnxUrl = 'https://ella.navgurukul.org/piper/model.onnx';
  static const _tokensUrl = 'https://ella.navgurukul.org/piper/tokens.txt';

  // espeak-ng-data — shared across all Piper models (~10MB tar.bz2)
  static const _espeakDataUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/espeak-ng-data.tar.bz2';

  static PiperModelService? _instance;
  static PiperModelService get instance => _instance ??= PiperModelService._();
  PiperModelService._();

  String? _modelOnnxPath;
  String? _tokensPath;
  String? _espeakDataDir;

  bool get isReady =>
      _modelOnnxPath != null &&
      _tokensPath != null &&
      _espeakDataDir != null;

  String? get modelOnnxPath => _modelOnnxPath;
  String? get tokensPath => _tokensPath;
  String? get espeakDataDir => _espeakDataDir;

  /// Returns true and populates paths if all required files are present and valid.
  Future<bool> checkIfDownloaded() async {
    final dir = await getApplicationDocumentsDirectory();
    final onnxFile = File('${dir.path}/piper_model.onnx');
    final tokensFile = File('${dir.path}/piper_tokens.txt');
    final espeakDir = Directory('${dir.path}/espeak-ng-data');

    if (await onnxFile.exists() &&
        (await onnxFile.length()) > 1000000 &&
        await tokensFile.exists() &&
        (await tokensFile.length()) > 10 &&
        await espeakDir.exists()) {
      _modelOnnxPath = onnxFile.path;
      _tokensPath = tokensFile.path;
      _espeakDataDir = espeakDir.path;
      debugPrint('PiperModelService: all files present ✓');
      return true;
    }
    return false;
  }

  /// Downloads all required files. Reports [onProgress] (0.0–1.0).
  /// Resumes from partial `.part` downloads if interrupted.
  ///
  /// Download breakdown:
  ///   0–5%   tokens.txt  (~1KB, instant)
  ///   5–73%  model.onnx  (~61MB)
  ///   73–90% espeak-ng-data.tar.bz2 (~10MB)
  ///   90–99% extract espeak-ng-data
  Future<bool> downloadModel({
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final onnxPath = '${dir.path}/piper_model.onnx';
      final tokensPath = '${dir.path}/piper_tokens.txt';
      final espeakTarPath = '${dir.path}/espeak-ng-data.tar.bz2';
      final espeakDirPath = '${dir.path}/espeak-ng-data';

      // 1. Download tokens.txt (tiny)
      onProgress?.call(0.0, 'Downloading voice model...');
      await _downloadFile(_tokensUrl, tokensPath, (p) {
        onProgress?.call(p * 0.05, 'Downloading voice model...');
      });

      // 2. Download model.onnx (~61MB)
      await _downloadFile(_modelOnnxUrl, onnxPath, (p) {
        onProgress?.call(0.05 + p * 0.68, 'Downloading voice model...');
      });

      // 3. Download espeak-ng-data.tar.bz2 (~10MB)
      onProgress?.call(0.73, 'Downloading voice data...');
      await _downloadFile(_espeakDataUrl, espeakTarPath, (p) {
        onProgress?.call(0.73 + p * 0.17, 'Downloading voice data...');
      });

      // 4. Extract espeak-ng-data
      onProgress?.call(0.90, 'Extracting voice data...');
      await compute(_extractTarBz2, {'archive': espeakTarPath, 'dest': dir.path});
      final tarFile = File(espeakTarPath);
      if (await tarFile.exists()) await tarFile.delete();
      onProgress?.call(0.99, 'Finalizing...');

      _modelOnnxPath = onnxPath;
      _tokensPath = tokensPath;
      _espeakDataDir = espeakDirPath;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_modelDownloadedKey, true);

      onProgress?.call(1.0, 'Voice model ready!');
      debugPrint('PiperModelService: download complete ✓');
      return true;
    } catch (e) {
      debugPrint('PiperModelService: download failed: $e');
      return false;
    }
  }

  /// Top-level function for use with [compute] (must not be a closure).
  static Future<void> _extractTarBz2(Map<String, String> args) async {
    final archivePath = args['archive']!;
    final destDir = args['dest']!;

    final bytes = await File(archivePath).readAsBytes();
    final tarBytes = BZip2Decoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    for (final file in archive) {
      final filePath = '$destDir/${file.name}';
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }
  }

  /// Downloads [url] to [savePath] using an intermediate `.part` file.
  /// Supports HTTP Range requests for resuming interrupted downloads.
  Future<void> _downloadFile(
    String url,
    String savePath,
    void Function(double) onProgress,
  ) async {
    final finalFile = File(savePath);
    if (await finalFile.exists()) {
      onProgress(1.0);
      return;
    }

    final tempPath = '$savePath.part';
    final tempFile = File(tempPath);
    int existingLength = 0;
    if (await tempFile.exists()) {
      existingLength = await tempFile.length();
    }

    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(url));
      if (existingLength > 0) {
        request.headers['Range'] = 'bytes=$existingLength-';
      }

      var response = await client.send(request);

      // Handle 416 (Requested Range Not Satisfiable) by clearing temp file and restarting
      if (response.statusCode == 416 && existingLength > 0) {
        await tempFile.delete();
        existingLength = 0;
        final freshRequest = http.Request('GET', Uri.parse(url));
        response = await client.send(freshRequest);
      }

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('HTTP ${response.statusCode} for $url');
      }

      final isPartial = response.statusCode == 206;
      final contentLength = response.contentLength ?? 0;
      final totalBytes = isPartial ? existingLength + contentLength : contentLength;
      int receivedBytes = isPartial ? existingLength : 0;

      if (!isPartial && existingLength > 0) {
        // Server returned 200 (full content), overwrite partial file
        sink = tempFile.openWrite(mode: FileMode.write);
      } else {
        sink = tempFile.openWrite(mode: FileMode.append);
      }

      if (totalBytes > 0) {
        onProgress(receivedBytes / totalBytes);
      }

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Atomically move the completed .part file to final savePath
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(savePath);
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Deletes all cached model files (e.g. to free space or force re-download).
  Future<void> clearModel() async {
    final dir = await getApplicationDocumentsDirectory();
    for (final name in [
      'piper_model.onnx',
      'piper_model.onnx.part',
      'piper_tokens.txt',
      'piper_tokens.txt.part',
      'espeak-ng-data.tar.bz2',
      'espeak-ng-data.tar.bz2.part',
    ]) {
      final f = File('${dir.path}/$name');
      if (await f.exists()) await f.delete();
    }
    final espeakDir = Directory('${dir.path}/espeak-ng-data');
    if (await espeakDir.exists()) await espeakDir.delete(recursive: true);

    _modelOnnxPath = null;
    _tokensPath = null;
    _espeakDataDir = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modelDownloadedKey);
  }
}
