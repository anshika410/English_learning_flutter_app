import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Whisper API STT — records audio via platform channel, sends to OpenAI's
/// /audio/transcriptions endpoint, returns transcript.
class WhisperSttService {
  static const _channel = MethodChannel('whisper_recorder');
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  String get _baseUrl =>
      dotenv.env['OPENAI_BASE_URL'] ?? 'https://api.openai.com/v1';

  Future<bool> initialize() async {
    try {
      final available =
          await _channel.invokeMethod<bool>('isAvailable') ?? false;
      debugPrint('Whisper STT: Available: $available, API key set: ${_apiKey.isNotEmpty}');
      return available && _apiKey.isNotEmpty;
    } catch (e) {
      debugPrint('Whisper STT: Init failed: $e');
      return false;
    }
  }

  Future<bool> startRecording({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    if (_isRecording) return false;
    if (_apiKey.isEmpty) {
      debugPrint('Whisper STT: No OpenAI API key');
      return false;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final path = p.join(tempDir.path, 'whisper_recording.m4a');

      final started = await _channel.invokeMethod<bool>('startRecording', {
        'path': path,
      });

      if (started == true) {
        _isRecording = true;
        debugPrint('Whisper STT: Recording started');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Whisper STT: Start failed: $e');
      return false;
    }
  }

  Future<String?> stopAndTranscribe() async {
    if (!_isRecording) return null;

    try {
      final filePath =
          await _channel.invokeMethod<String>('stopRecording');
      _isRecording = false;
      debugPrint('Whisper STT: Stopped, file: $filePath');

      if (filePath == null || filePath.isEmpty) return null;

      final transcript = await _transcribe(filePath);
      debugPrint('Whisper STT: "$transcript"');
      return transcript;
    } catch (e) {
      _isRecording = false;
      debugPrint('Whisper STT: Error: $e');
      return null;
    }
  }

  Future<String> _transcribe(String filePath) async {
    final uri = Uri.parse('$_baseUrl/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $_apiKey';
    request.fields['model'] = 'whisper-1';
    request.fields['language'] = 'en';
    request.fields['response_format'] = 'json';

    final file = File(filePath);
    final ext = p.extension(filePath).replaceFirst('.', '');
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      filePath,
      contentType: MediaType('audio', ext.isEmpty ? 'm4a' : ext),
    ));

    debugPrint('Whisper STT: Sending ${file.lengthSync()} bytes to API');
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
          'Whisper API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    return (data['text'] as String?)?.trim() ?? '';
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
