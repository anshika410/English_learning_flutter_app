import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/chat_message.dart';
import '../models/latency_info.dart';
import '../services/llm_service.dart';
import '../services/stt_service.dart';
import '../services/whisper_stt_service.dart';
import '../services/tts_manager.dart';
import '../services/tts_service.dart';

enum SttEngineType { system, whisper }

class ChatProvider extends ChangeNotifier {
  final LlmService _llm = LlmService();
  final SttService _stt = SttService();
  final WhisperSttService _whisperStt = WhisperSttService();
  final TtsManager _tts = TtsManager();

  SttEngineType _sttEngineType = SttEngineType.system;
  bool _whisperAvailable = false;

  final List<ChatMessage> _messages = [];
  String _currentTranscript = '';
  bool _isListening = false;
  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _autoSpeak = true;
  bool _showLatency = true;

  // Latency tracking
  DateTime? _sttStartTime; // when mic was tapped
  DateTime? _lastSpeechTime; // last time we got partial results (user still speaking)
  Duration? _lastSttProcessingDuration; // silence → final transcript
  Duration? _lastSttSpeakingDuration; // how long user spoke

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String get currentTranscript => _currentTranscript;
  bool get isListening => _isListening;
  bool get isLoading => _isLoading;
  bool get isSpeaking => _isSpeaking;
  bool get autoSpeak => _autoSpeak;
  bool get showLatency => _showLatency;

  // TTS engine info
  TtsEngineType get ttsEngineType => _tts.activeType;
  bool get piperAvailable => _tts.piperAvailable;
  List<PiperVoice> get piperVoices => _tts.piperEngine.availableVoices;
  PiperVoice? get currentPiperVoice => _tts.piperEngine.currentVoice;

  // LLM provider info
  LlmProvider get llmProvider => _llm.activeProvider;
  List<LlmProvider> get availableLlmProviders => _llm.availableProviders;
  String get llmProviderName => _llm.activeConfig.name;
  String get llmModelName => _llm.activeConfig.model;

  void setLlmProvider(LlmProvider provider) {
    _llm.setProvider(provider);
    notifyListeners();
  }

  // STT engine info
  SttEngineType get sttEngineType => _sttEngineType;
  bool get whisperAvailable => _whisperAvailable;

  void setSttEngine(SttEngineType type) {
    _sttEngineType = type;
    notifyListeners();
  }

  Future<void> initialize() async {
    await _stt.initialize();
    _whisperAvailable = await _whisperStt.initialize();
    debugPrint('Whisper on-device available: $_whisperAvailable (model loaded: ${_whisperStt.isAvailable})');
    await _tts.initialize();
    _messages.add(ChatMessage(
      role: MessageRole.assistant,
      content:
          "Hi! I'm Ella, your English tutor. Let's practice together! "
          "You can type or tap the microphone to speak. "
          "What would you like to talk about today?",
    ));
    notifyListeners();
  }

  void toggleAutoSpeak() {
    _autoSpeak = !_autoSpeak;
    notifyListeners();
  }

  void toggleShowLatency() {
    _showLatency = !_showLatency;
    notifyListeners();
  }

  void setTtsEngine(TtsEngineType type) {
    _tts.setEngine(type);
    notifyListeners();
  }

  void setPiperVoice(PiperVoice voice) {
    _tts.piperEngine.setVoice(voice);
    notifyListeners();
  }

  Future<void> refreshPiperVoices() async {
    await _tts.refreshPiperVoices();
    notifyListeners();
  }

  Future<void> toggleListening() async {
    if (_isListening) {
      if (_sttEngineType == SttEngineType.whisper) {
        // Whisper: stop recording and transcribe
        _currentTranscript = 'Transcribing...';
        notifyListeners();
        final sttStart = DateTime.now();
        final transcript = await _whisperStt.stopAndTranscribe();
        final sttDuration = DateTime.now().difference(sttStart);
        _isListening = false;
        _currentTranscript = '';
        notifyListeners();
        if (transcript != null && transcript.isNotEmpty) {
          await sendMessage(transcript, sttDuration: sttDuration);
        }
        _sttStartTime = null;
      } else {
        await _stt.stopListening();
        await _finishListening();
      }
    } else {
      _currentTranscript = '';
      _sttStartTime = DateTime.now();
      _lastSpeechTime = null;
      _isListening = true;
      notifyListeners();

      if (_sttEngineType == SttEngineType.whisper) {
        final started = await _whisperStt.startRecording();
        if (!started) {
          debugPrint('Whisper STT: Could not start recording');
          _isListening = false;
          notifyListeners();
        }
      } else {
        final started = await _stt.startListening(
          onResult: _onSpeechResult,
          onDone: _onListeningDone,
        );
        if (!started) {
          debugPrint('STT: Could not start listening');
          _isListening = false;
          notifyListeners();
        }
      }
    }
  }

  /// Called when speech recognition stops naturally (timeout/silence).
  void _onListeningDone() {
    if (_isListening) {
      _finishListening();
    }
  }

  Future<void> _finishListening() async {
    // STT processing latency = time from last speech to now (when final result is ready)
    if (_lastSpeechTime != null) {
      _lastSttProcessingDuration = DateTime.now().difference(_lastSpeechTime!);
    }
    // Speaking duration = last speech time - mic start
    if (_sttStartTime != null && _lastSpeechTime != null) {
      _lastSttSpeakingDuration = _lastSpeechTime!.difference(_sttStartTime!);
    }

    _isListening = false;
    notifyListeners();

    if (_currentTranscript.isNotEmpty) {
      await sendMessage(
        _currentTranscript,
        sttDuration: _lastSttProcessingDuration,
        sttSpeakingDuration: _lastSttSpeakingDuration,
      );
    }
    _currentTranscript = '';
    _lastSttProcessingDuration = null;
    _lastSttSpeakingDuration = null;
    _sttStartTime = null;
    _lastSpeechTime = null;
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _currentTranscript = result.recognizedWords;
    // Track when user is actively speaking (partial results coming in)
    if (!result.finalResult) {
      _lastSpeechTime = DateTime.now();
    }
    debugPrint('STT result: "${result.recognizedWords}" final=${result.finalResult}');
    notifyListeners();
  }

  Future<void> sendMessage(String text, {Duration? sttDuration, Duration? sttSpeakingDuration}) async {
    if (text.trim().isEmpty) return;

    final turnStart = DateTime.now();
    _messages.add(ChatMessage(role: MessageRole.user, content: text.trim()));
    _isLoading = true;
    notifyListeners();

    Duration? llmDuration;
    Duration? ttsDuration;

    try {
      // --- LLM ---
      final llmStart = DateTime.now();
      final reply = await _llm.sendMessage(_messages);
      llmDuration = DateTime.now().difference(llmStart);

      // --- TTS ---
      if (_autoSpeak) {
        _isSpeaking = true;
        notifyListeners();
        final ttsStart = DateTime.now();
        await _tts.speak(reply.content);
        ttsDuration = DateTime.now().difference(ttsStart);
        _isSpeaking = false;
      }

      final totalDuration = DateTime.now().difference(turnStart);
      final latency = LatencyInfo(
        sttDuration: sttDuration,
        sttSpeakingDuration: sttSpeakingDuration,
        llmDuration: llmDuration,
        ttsDuration: ttsDuration,
        totalDuration: totalDuration,
      );

      debugPrint('⏱ ${latency.summary}');

      _messages.add(ChatMessage(
        role: reply.role,
        content: reply.content,
        correction: reply.correction,
        latency: latency,
      ));
    } catch (e) {
      final totalDuration = DateTime.now().difference(turnStart);
      final latency = LatencyInfo(
        sttDuration: sttDuration,
        sttSpeakingDuration: sttSpeakingDuration,
        llmDuration: llmDuration ?? totalDuration,
        totalDuration: totalDuration,
      );

      debugPrint('⏱ ERROR turn: ${latency.summary}');
      debugPrint('⏱ Error details: $e');

      _messages.add(ChatMessage(
        role: MessageRole.assistant,
        content: 'Sorry, I had trouble responding. Please try again.\n($e)',
        latency: latency,
      ));
    } finally {
      _isLoading = false;
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> speakMessage(String text) async {
    _isSpeaking = true;
    notifyListeners();
    await _tts.speak(text);
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stt.dispose();
    _whisperStt.dispose();
    _tts.dispose();
    super.dispose();
  }
}
