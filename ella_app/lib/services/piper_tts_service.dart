import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'stt_tts_service.dart';
import 'piper_model_service.dart';
import 'audio_service.dart';

class _WordSpan {
  final int start;
  final int end;
  const _WordSpan(this.start, this.end);
}

/// Paths needed to rebuild the sherpa TTS engine inside a background isolate.
class _TtsGenArgs {
  final String modelPath;
  final String tokensPath;
  final String dataDir;
  final String text;
  const _TtsGenArgs({
    required this.modelPath,
    required this.tokensPath,
    required this.dataDir,
    required this.text,
  });
}

/// Result of a TTS generation run.
class _TtsGenResult {
  final Float32List samples;
  final int sampleRate;
  const _TtsGenResult(this.samples, this.sampleRate);
}

/// Runs sherpa-onnx TTS generation in a background isolate so the heavy native
/// VITS inference never blocks the UI thread (which caused an ANR).
///
/// The sherpa native handle cannot cross isolates, so we rebuild a fresh
/// [sherpa.OfflineTts] from the model paths inside the isolate, generate, and
/// free it before returning only the PCM samples.
Future<_TtsGenResult> _generateInIsolate(_TtsGenArgs args) {
  return Isolate.run(() {
    sherpa.initBindings();
    final config = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: args.modelPath,
          lexicon: '',
          tokens: args.tokensPath,
          dataDir: args.dataDir,
          noiseScale: 0.667,
          noiseScaleW: 0.8,
          lengthScale: 1.0,
        ),
        debug: false,
        numThreads: 4,
        provider: 'cpu',
      ),
      maxNumSenetences: 1,
    );
    final tts = sherpa.OfflineTts(config);
    try {
      final audio = tts.generate(text: args.text, sid: 0, speed: 1.0);
      return _TtsGenResult(audio.samples, audio.sampleRate);
    } finally {
      tts.free();
    }
  });
}

/// On-device TTS using the NavGurukul Indian accent Piper model via sherpa-onnx.
/// Emits [progressStream] for word highlighting and supports instant stopping.
class PiperTtsService implements TtsInterface {
  sherpa.OfflineTts? _tts;
  AudioPlayer? _player;
  bool _initialized = false;
  bool _speaking = false;

  int _speakToken = 0;
  Completer<void>? _activeCompleter;

  final _progressController = StreamController<TtsProgressEvent>.broadcast();
  @override
  Stream<TtsProgressEvent> get progressStream => _progressController.stream;

  final _doneController = StreamController<void>.broadcast();
  @override
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
            tokens: modelService.tokensPath!,
            dataDir: modelService.espeakDataDir!,
            noiseScale: 0.667,
            noiseScaleW: 0.8,
            lengthScale: 1.0,
          ),
          debug: false,
          numThreads: 4,
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
      await initialize();
      if (!_initialized || _tts == null) {
        debugPrint('PiperTtsService: not initialized, cannot speak');
        return;
      }
    }

    final sanitized = sanitizeTtsText(text);
    if (sanitized.trim().isEmpty) return;

    // Stop any existing playback first
    await stop();

    final token = ++_speakToken;
    _speaking = true;

    final sw = Stopwatch()..start();
    final t0 = sw.elapsedMilliseconds;

    try {
      // Duck background music
      unawaited(AudioService.maybeInstance?.duckForSpeech());

      final spans = <_WordSpan>[];
      final regex = RegExp(r'\S+');
      for (final m in regex.allMatches(sanitized)) {
        spans.add(_WordSpan(m.start, m.end));
      }

      // Generate single-pass audio for the entire response text
      final audio = _tts!.generate(text: sanitized, sid: 0, speed: 1.0);
      final tGen = sw.elapsedMilliseconds;

      debugPrint(
        '⏱️ [PiperTTS Single-Pass] Audio ready in ${tGen - t0}ms | length=${sanitized.length} chars',
      );

      if (token != _speakToken || !_speaking) return;
      if (audio.samples.isEmpty) return;

      final completer = Completer<void>();
      _activeCompleter = completer;

      await _playAudioSamples(
        audio.samples,
        audio.sampleRate,
        completer,
        spans,
        token: token,
      );

      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      debugPrint('PiperTtsService: speak failed: $e');
    } finally {
      if (token == _speakToken) {
        _speaking = false;
        _activeCompleter = null;
        _progressController.add(const TtsProgressEvent(0, 0));
        unawaited(AudioService.maybeInstance?.unduckAfterSpeech());
        _doneController.add(null);
      }
    }
  }

  /// Convert float32 PCM samples to WAV and play via audioplayers.
  Future<void> _playAudioSamples(
    Float32List samples,
    int sampleRate,
    Completer<void> completer,
    List<_WordSpan> spans, {
    required int token,
  }) async {
    AudioPlayer? player;
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

      final headerBytes = header.buffer.asUint8List();
      final wavBytes = Uint8List(headerBytes.length + dataBytes.length);
      wavBytes.setRange(0, headerBytes.length, headerBytes);
      wavBytes.setRange(headerBytes.length, wavBytes.length, dataBytes);
      await wavFile.writeAsBytes(wavBytes, flush: false);

      if (token != _speakToken || !_speaking) {
        if (!completer.isCompleted) completer.complete();
        return;
      }

      final durationMs = ((samples.length / sampleRate) * 1000).round();
      player = AudioPlayer();
      _player = player;

      player.onPositionChanged.listen((pos) {
        if (token != _speakToken || !_speaking || spans.isEmpty || durationMs <= 0) return;
        final progress = (pos.inMilliseconds / durationMs).clamp(0.0, 1.0);
        final wordIdx =
            (progress * spans.length).floor().clamp(0, spans.length - 1);
        final span = spans[wordIdx];
        _progressController.add(TtsProgressEvent(span.start, span.end));
      });

      player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
        player?.dispose();
        if (_player == player) _player = null;
      });

      await player.play(DeviceFileSource(wavFile.path));
      if (token == _speakToken && _speaking) {
        final firstEnd = spans.isNotEmpty ? spans[0].end : 0;
        _progressController.add(TtsProgressEvent(spans.isNotEmpty ? spans[0].start : 0, firstEnd));
      }
    } catch (e) {
      debugPrint('PiperTtsService: playback error: $e');
      if (player != null && _player == player) {
        try {
          await player.dispose();
        } catch (_) {}
        _player = null;
      }
      if (!completer.isCompleted) completer.complete();
    }
  }

  @override
  Future<void> stop() async {
    _speakToken++;
    _speaking = false;
    final c = _activeCompleter;
    _activeCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    if (_player != null) {
      final playerToStop = _player;
      _player = null;
      try {
        await playerToStop?.stop();
        await playerToStop?.dispose();
      } catch (e) {
        debugPrint('PiperTtsService: error stopping player: $e');
      }
    }
    _progressController.add(const TtsProgressEvent(0, 0));
    unawaited(AudioService.maybeInstance?.unduckAfterSpeech());
    _doneController.add(null);
  }

  @override
  bool get isSpeaking => _speaking;

  void dispose() {
    stop();
    _tts?.free();
    _doneController.close();
    _progressController.close();
  }
}
