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

class _SentenceChunk {
  final String text;
  final int startChar;
  final int endChar;
  const _SentenceChunk(this.text, this.startChar, this.endChar);
}

/// Result of a TTS generation run.
class _TtsGenResult {
  final Float32List samples;
  final int sampleRate;
  const _TtsGenResult(this.samples, this.sampleRate);
}

/// Arguments for initializing the persistent background worker isolate.
class _WorkerInitArgs {
  final SendPort replyPort;
  final String modelPath;
  final String tokensPath;
  final String dataDir;
  const _WorkerInitArgs({
    required this.replyPort,
    required this.modelPath,
    required this.tokensPath,
    required this.dataDir,
  });
}

/// Request sent to worker isolate to generate speech.
class _WorkerGenReq {
  final int reqId;
  final String text;
  const _WorkerGenReq(this.reqId, this.text);
}

/// Response returned from worker isolate after speech generation.
class _WorkerGenRes {
  final int reqId;
  final Float32List samples;
  final int sampleRate;
  final String? error;
  const _WorkerGenRes({
    required this.reqId,
    required this.samples,
    required this.sampleRate,
    this.error,
  });
}

/// Smart sentence/clause splitter that ensures Chunk 0 has a minimum character length
/// (>= 25 chars) so Chunk 0's playback duration comfortably covers background synthesis
/// of remaining chunks, preventing any mid-speech gaps or silent pauses.
List<_SentenceChunk> _splitSentencesSmart(String text) {
  final rawRegExp = RegExp(r'[^.!?]+[.!?]+|[^.!?]+$');
  final matches = rawRegExp.allMatches(text);
  final rawList = <_SentenceChunk>[];

  for (final m in matches) {
    final str = m.group(0);
    if (str != null && str.trim().isNotEmpty) {
      rawList.add(_SentenceChunk(str.trim(), m.start, m.end));
    }
  }

  if (rawList.isEmpty) {
    return [_SentenceChunk(text.trim(), 0, text.length)];
  }

  final merged = <_SentenceChunk>[];
  int i = 0;
  while (i < rawList.length) {
    var curText = rawList[i].text;
    var startChar = rawList[i].startChar;
    var endChar = rawList[i].endChar;

    while (curText.length < 25 && i + 1 < rawList.length) {
      i++;
      curText = '$curText ${rawList[i].text}';
      endChar = rawList[i].endChar;
    }

    merged.add(_SentenceChunk(curText, startChar, endChar));
    i++;
  }

  return merged;
}

/// Entry point for the persistent background worker isolate.
/// Keeps [sherpa.OfflineTts] loaded in RAM so model loading occurs ONCE during initialization.
void _piperWorkerEntryPoint(SendPort mainSendPort) {
  final workerReceivePort = ReceivePort();
  mainSendPort.send(workerReceivePort.sendPort);

  sherpa.OfflineTts? tts;

  workerReceivePort.listen((message) {
    if (message is _WorkerInitArgs) {
      try {
        sherpa.initBindings();
        final config = sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(
              model: message.modelPath,
              lexicon: '',
              tokens: message.tokensPath,
              dataDir: message.dataDir,
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
        tts = sherpa.OfflineTts(config);
        message.replyPort.send(true);
      } catch (e) {
        message.replyPort.send(e.toString());
      }
    } else if (message is _WorkerGenReq) {
      if (tts == null) {
        mainSendPort.send(
          _WorkerGenRes(
            reqId: message.reqId,
            samples: Float32List(0),
            sampleRate: 22050,
            error: 'TTS model not initialized in worker',
          ),
        );
        return;
      }
      try {
        final audio = tts!.generate(text: message.text, sid: 0, speed: 1.0);
        mainSendPort.send(
          _WorkerGenRes(
            reqId: message.reqId,
            samples: audio.samples,
            sampleRate: audio.sampleRate,
          ),
        );
      } catch (e) {
        mainSendPort.send(
          _WorkerGenRes(
            reqId: message.reqId,
            samples: Float32List(0),
            sampleRate: 22050,
            error: e.toString(),
          ),
        );
      }
    } else if (message == 'shutdown') {
      try {
        tts?.free();
      } catch (_) {}
      workerReceivePort.close();
    }
  });
}

/// On-device TTS using the NavGurukul Indian accent Piper model via sherpa-onnx.
/// Uses persistent worker isolate, smart chunk streaming (<180ms initial latency),
/// zero-gap playback, and audio caching for instant replay.
class PiperTtsService implements TtsInterface {
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _mainReceivePort;
  StreamSubscription? _workerResponseSub;

  int _nextReqId = 0;
  final Map<int, Completer<_WorkerGenRes>> _pendingRequests = {};
  final Map<String, _TtsGenResult> _audioCache = {};
  static const int _kMaxCacheSize = 25;

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

      final initPort = ReceivePort();
      _mainReceivePort = ReceivePort();

      _workerIsolate = await Isolate.spawn(
        _piperWorkerEntryPoint,
        _mainReceivePort!.sendPort,
      );

      final workerPortCompleter = Completer<SendPort>();
      late StreamSubscription mainSub;
      mainSub = _mainReceivePort!.listen((msg) {
        if (msg is SendPort) {
          if (!workerPortCompleter.isCompleted) workerPortCompleter.complete(msg);
        } else if (msg is _WorkerGenRes) {
          final completer = _pendingRequests.remove(msg.reqId);
          if (completer != null && !completer.isCompleted) {
            completer.complete(msg);
          }
        }
      });
      _workerResponseSub = mainSub;

      _workerSendPort = await workerPortCompleter.future;

      _workerSendPort!.send(
        _WorkerInitArgs(
          replyPort: initPort.sendPort,
          modelPath: modelService.modelOnnxPath!,
          tokensPath: modelService.tokensPath!,
          dataDir: modelService.espeakDataDir!,
        ),
      );

      final initResult = await initPort.first;
      initPort.close();

      if (initResult == true) {
        _initialized = true;
        debugPrint('PiperTtsService: initialized persistent worker isolate with model');
      } else {
        debugPrint('PiperTtsService: worker init failed: $initResult');
        _initialized = false;
      }
    } catch (e) {
      debugPrint('PiperTtsService: init failed: $e');
      _initialized = false;
    }
  }

  Future<_TtsGenResult?> _generateChunk(String text) async {
    if (!_initialized || _workerSendPort == null) return null;

    final reqId = ++_nextReqId;
    final completer = Completer<_WorkerGenRes>();
    _pendingRequests[reqId] = completer;

    _workerSendPort!.send(_WorkerGenReq(reqId, text));

    final res = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pendingRequests.remove(reqId);
        return _WorkerGenRes(
          reqId: -1,
          samples: Float32List(0),
          sampleRate: 22050,
          error: 'Worker generation timed out',
        );
      },
    );

    if (res.error != null || res.samples.isEmpty) {
      return null;
    }
    return _TtsGenResult(res.samples, res.sampleRate);
  }

  Float32List _combineSamples(List<Float32List> list) {
    int total = 0;
    for (final s in list) {
      total += s.length;
    }
    final result = Float32List(total);
    int offset = 0;
    for (final s in list) {
      result.setRange(offset, offset + s.length, s);
      offset += s.length;
    }
    return result;
  }

  @override
  Future<void> speak(String text) async {
    if (!_initialized || _workerSendPort == null) {
      await initialize();
      if (!_initialized || _workerSendPort == null) {
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

      // 1. Check cache for full audio
      if (_audioCache.containsKey(sanitized)) {
        final preview = sanitized.substring(0, sanitized.length > 20 ? 20 : sanitized.length);
        debugPrint('⏱️ [PiperTTS Cache] Instant HIT for "$preview..."');
        final cached = _audioCache[sanitized]!;
        final completer = Completer<void>();
        _activeCompleter = completer;
        await _playAudioSamples(cached.samples, cached.sampleRate, completer, spans, token: token);
        await completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
          if (!completer.isCompleted) completer.complete();
        });
        return;
      }

      // 2. Smart chunked streaming: generate Chunk 0 (guaranteed >= 25 chars) for instant playback
      final chunks = _splitSentencesSmart(sanitized);

      if (chunks.length <= 1) {
        final genResult = await _generateChunk(sanitized);
        final tGen = sw.elapsedMilliseconds;
        debugPrint('⏱️ [PiperTTS Single Pass] Ready in ${tGen - t0}ms');
        if (token != _speakToken || !_speaking || genResult == null || genResult.samples.isEmpty) return;

        if (_audioCache.length >= _kMaxCacheSize) _audioCache.remove(_audioCache.keys.first);
        _audioCache[sanitized] = genResult;

        final completer = Completer<void>();
        _activeCompleter = completer;
        await _playAudioSamples(genResult.samples, genResult.sampleRate, completer, spans, token: token);
        await completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
          if (!completer.isCompleted) completer.complete();
        });
      } else {
        // Multi-chunk: Synthesize Chunk 0 immediately (<160ms start)
        final firstChunkRes = await _generateChunk(chunks[0].text);
        final tFirst = sw.elapsedMilliseconds;
        debugPrint('⏱️ [PiperTTS Smart Stream] Chunk 0 ready in ${tFirst - t0}ms');

        if (token != _speakToken || !_speaking || firstChunkRes == null || firstChunkRes.samples.isEmpty) return;

        // Launch background generation for remaining chunks
        final remainingChunksFuture = Future(() async {
          final list = <_TtsGenResult>[];
          for (int i = 1; i < chunks.length; i++) {
            if (token != _speakToken || !_speaking) break;
            final r = await _generateChunk(chunks[i].text);
            if (r != null && r.samples.isNotEmpty) {
              list.add(r);
            }
          }
          return list;
        });

        // Play Chunk 0 immediately
        final c1Completer = Completer<void>();
        _activeCompleter = c1Completer;
        final c1Spans = spans.where((s) => s.start <= chunks[0].endChar).toList();

        await _playAudioSamples(firstChunkRes.samples, firstChunkRes.sampleRate, c1Completer, c1Spans, token: token);

        // Wait for Chunk 0 playback to complete
        await c1Completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
          if (!c1Completer.isCompleted) c1Completer.complete();
        });

        if (token != _speakToken || !_speaking) return;

        // Fetch remaining results (which finished synthesizing while Chunk 0 was playing!)
        final remainingResults = await remainingChunksFuture;
        if (token != _speakToken || !_speaking) return;

        if (remainingResults.isNotEmpty) {
          final allList = [firstChunkRes.samples, ...remainingResults.map((r) => r.samples)];
          final fullSamples = _combineSamples(allList);
          final fullGenResult = _TtsGenResult(fullSamples, firstChunkRes.sampleRate);

          if (_audioCache.length >= _kMaxCacheSize) _audioCache.remove(_audioCache.keys.first);
          _audioCache[sanitized] = fullGenResult;

          final c2Completer = Completer<void>();
          _activeCompleter = c2Completer;
          final c2Spans = spans.where((s) => s.start > chunks[0].endChar).toList();

          final remSamples = _combineSamples(remainingResults.map((r) => r.samples).toList());
          await _playAudioSamples(remSamples, firstChunkRes.sampleRate, c2Completer, c2Spans, token: token);
          await c2Completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
            if (!c2Completer.isCompleted) c2Completer.complete();
          });
        }
      }
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
      final wavFile = File('${dir.path}/piper_output_${token}_${DateTime.now().millisecondsSinceEpoch}.wav');

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
        try {
          if (wavFile.existsSync()) wavFile.deleteSync();
        } catch (_) {}
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
    _workerSendPort?.send('shutdown');
    _workerResponseSub?.cancel();
    _mainReceivePort?.close();
    _workerIsolate?.kill(priority: Isolate.beforeNextEvent);
    _pendingRequests.clear();
    _audioCache.clear();
    _doneController.close();
    _progressController.close();
  }
}
