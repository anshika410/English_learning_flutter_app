import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'stt_tts_service.dart';
import 'piper_model_service.dart';
import 'audio_service.dart';
/// On-device TTS using the NavGurukul Indian accent Piper model via sherpa-onnx.
/// Falls back gracefully if model is not downloaded yet.
class PiperTtsService implements TtsInterface {
  sherpa.OfflineTts? _tts;
  bool _initialized = false;
  bool _speaking = false;

  final _doneController = StreamController<void>.broadcast();
  Stream<void> get doneStream => _doneController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final modelService = PiperModelService.instance;
      final downloaded = await modelService.checkIfDownloaded();
      if (!downloaded) {
        debugPrint('PiperTtsService: model not downloaded yet, skipping init');
        return;
      }

      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: modelService.modelOnnxPath!,
            lexicon: '',
            tokens: '',
            dataDir: '',
            noiseScale: 0.667,
            noiseScaleW: 0.8,
            lengthScale: 1.0,
          ),
          debug: false,
          numThreads: 2,
          provider: 'cpu',
        ),
        // Note: typo in sherpa_onnx library — it's maxNumSenetences not maxNumSentences
        maxNumSenetences: 1,
      );

      _tts = sherpa.OfflineTts(config);
      _initialized = true;
      debugPrint('PiperTtsService: initialized with Indian accent model');
    } catch (e) {
      debugPrint('PiperTtsService: init failed: $e');
      _initialized = false;
    }
  }

  @override
  Future<void> speak(String text) async {
    if (!_initialized || _tts == null) {
      debugPrint('PiperTtsService: not initialized, cannot speak');
      return;
    }

    final sanitized = stripEmojis(text);
    if (sanitized.trim().isEmpty) return;

    _speaking = true;
    try {
      // Duck background music
      unawaited(AudioService.maybeInstance?.duckForSpeech());

      final audio = _tts!.generate(
        text: sanitized,
        sid: 0,
        speed: 1.0,
      );

      if (audio.samples.isEmpty) {
        debugPrint('PiperTtsService: empty audio generated');
        return;
      }

      // Write samples to WAV and play using audioplayers
      final completer = Completer<void>();
      await _playAudioSamples(audio.samples, audio.sampleRate, completer);
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('PiperTtsService: speak failed: $e');
    } finally {
      _speaking = false;
      unawaited(AudioService.maybeInstance?.unduckAfterSpeech());
      _doneController.add(null);
    }
  }

  /// Convert float32 PCM samples to WAV and play via audioplayers.
  Future<void> _playAudioSamples(
    Float32List samples,
    int sampleRate,
    Completer<void> completer,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final wavFile = File('${dir.path}/piper_output.wav');

      // Convert float32 → int16
      final int16 = Int16List(samples.length);
      for (int i = 0; i < samples.length; i++) {
        int16[i] = (samples[i] * 32767).clamp(-32768, 32767).toInt();
      }

      // Build WAV file
      final dataBytes = int16.buffer.asUint8List();
      final header = ByteData(44);
      void setStr(int offset, String s) {
        for (int i = 0; i < s.length; i++) {
          header.setUint8(offset + i, s.codeUnitAt(i));
        }
      }
      setStr(0, 'RIFF');
      header.setUint32(4, 36 + dataBytes.length, Endian.little);
      setStr(8, 'WAVE');
      setStr(12, 'fmt ');
      header.setUint32(16, 16, Endian.little);
      header.setUint16(20, 1, Endian.little); // PCM
      header.setUint16(22, 1, Endian.little); // mono
      header.setUint32(24, sampleRate, Endian.little);
      header.setUint32(28, sampleRate * 2, Endian.little);
      header.setUint16(32, 2, Endian.little);
      header.setUint16(34, 16, Endian.little);
      setStr(36, 'data');
      header.setUint32(40, dataBytes.length, Endian.little);

      await wavFile.writeAsBytes(
        [...header.buffer.asUint8List(), ...dataBytes],
      );

      // Play with audioplayers
      final player = AudioPlayer();
      player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
        player.dispose();
      });
      await player.play(DeviceFileSource(wavFile.path));
    } catch (e) {
      debugPrint('PiperTtsService: playback error: $e');
      if (!completer.isCompleted) completer.complete();
    }
  }

  @override
  Future<void> stop() async {
    _speaking = false;
    // sherpa-onnx doesn't have a mid-speech stop, audio will finish naturally
    unawaited(AudioService.maybeInstance?.unduckAfterSpeech());
    _doneController.add(null);
  }

  @override
  bool get isSpeaking => _speaking;

  void dispose() {
    _tts?.free();
    _doneController.close();
  }
}
