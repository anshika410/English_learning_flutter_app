import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/chat_message.dart';
import '../models/end_result_analysis.dart';
import '../models/focus_settings.dart';
import '../models/latency_info.dart';
import '../services/llm_service.dart';
import '../services/llm_service_base.dart';
import '../mock/mock_config.dart';
import '../services/stt_service.dart';
import '../services/continuous_stt_service.dart';
import '../services/native_stt_service.dart';
import '../services/whisper_stt_service.dart';
import '../services/tts_manager.dart';
import '../services/tts_service.dart';
import '../services/user_prefs_service.dart';
import '../utils/name_formatting.dart';

enum SttEngineType { system, continuous, whisper }

class ChatProvider extends ChangeNotifier {
  final LlmServiceBase _llm;

  ChatProvider({LlmServiceBase? llm}) : _llm = llm ?? createLlmService();

  /// Exposes the LLM service so PlacementScreen can share the same instance.
  LlmServiceBase get llmService => _llm;
  final SttService _stt = SttService();
  final ContinuousSttService _continuousStt = ContinuousSttService();
  final NativeSttService _nativeStt = NativeSttService();
  final WhisperSttService _whisperStt = WhisperSttService();
  final TtsManager _tts = TtsManager();
  final UserPrefsService _prefs = UserPrefsService();

  SttEngineType _sttEngineType = SttEngineType.system;
  bool _whisperAvailable = false;

  final List<ChatMessage> _messages = [];
  String _currentTranscript = '';
  bool _isListening = false;
  bool _isMicRecognizing = false; // true only when recognizer is actively running
  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _autoSpeak = true;
  bool _showLatency = true;
  bool _initialized = false;

  // User profile (set after placement)
  String? _userName;
  String? _userAge;
  String? _userLocation;
  String? _userLevel; // CEFR: A1, A2, B1, B2, C1
  String? _userLevelLabel;

  // Conversation session state
  String? _conversationTopic;
  bool _conversationComplete = false;

  // Focus settings & first-session tracking
  bool _hasCompletedFirstSession = false;
  FocusSettings _focusSettings = const FocusSettings.defaults();
  // True when focus settings should be injected into the next LLM turn.
  // Starts true so settings are always injected at session start.
  bool _focusSettingsDirty = true;

  // Latency tracking
  DateTime? _sttStartTime; // when mic was tapped
  DateTime?
  _lastSpeechTime; // last time we got partial results (user still speaking)
  Duration? _lastSttProcessingDuration; // silence → final transcript
  Duration? _lastSttSpeakingDuration; // how long user spoke

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String get currentTranscript => _currentTranscript;
  bool get isListening => _isListening;
  bool get isMicRecognizing => _isMicRecognizing;
  bool get isLoading => _isLoading;
  bool get isSpeaking => _isSpeaking;
  bool get autoSpeak => _autoSpeak;
  bool get showLatency => _showLatency;

  // TTS engine info
  TtsEngineType get ttsEngineType => _tts.activeType;
  bool get piperAvailable => _tts.piperAvailable;
  List<PiperVoice> get piperVoices => _tts.piperEngine.availableVoices;
  PiperVoice? get currentPiperVoice => _tts.piperEngine.currentVoice;

  // User profile getters
  String? get userName => _userName;
  String? get userAge => _userAge;
  String? get userLocation => _userLocation;
  String? get userLevel => _userLevel;
  String? get userLevelLabel => _userLevelLabel;

  // Conversation session getters
  String? get conversationTopic => _conversationTopic;
  bool get conversationComplete => _conversationComplete;

  /// Whether the user has already completed placement (persisted).
  bool get hasCompletedPlacement => _userLevel != null;

  void setUserProfile({
    String? name,
    String? age,
    String? location,
    String? level,
    String? levelLabel,
  }) {
    final normalizedName = name == null ? null : normalizeDisplayName(name);
    _userName = normalizedName ?? _userName;
    _userAge = age ?? _userAge;
    _userLocation = location ?? _userLocation;
    _userLevel = level ?? _userLevel;
    _userLevelLabel = levelLabel ?? _userLevelLabel;
    _prefs.saveProfile(
      name: normalizedName,
      age: age,
      location: location,
      level: level,
      levelLabel: levelLabel,
    );
    notifyListeners();
  }

  // Focus settings & first-session tracking
  bool get hasCompletedFirstSession => _hasCompletedFirstSession;
  FocusSettings get focusSettings => _focusSettings;

  void markFirstSessionComplete() {
    _hasCompletedFirstSession = true;
    _prefs.setFirstSessionComplete();
    notifyListeners();
  }

  void updateFocusSettings(FocusSettings settings) {
    _focusSettings = settings;
    _focusSettingsDirty = true;
    _prefs.saveFocusSettings(settings);
    notifyListeners();
  }

  // LLM provider info (only meaningful when using the real LlmService)
  LlmProvider get llmProvider {
    final llm = _llm;
    return llm is LlmService ? llm.activeProvider : LlmProvider.deepseek;
  }

  List<LlmProvider> get availableLlmProviders {
    final llm = _llm;
    return llm is LlmService ? llm.availableProviders : const [];
  }

  String get llmProviderName {
    final llm = _llm;
    return llm is LlmService ? llm.activeConfig.name : 'Mock';
  }

  String get llmModelName {
    final llm = _llm;
    return llm is LlmService ? llm.activeConfig.model : 'mock';
  }

  void setLlmProvider(LlmProvider provider) {
    final llm = _llm;
    if (llm is LlmService) llm.setProvider(provider);
    notifyListeners();
  }

  // STT engine info
  SttEngineType get sttEngineType => _sttEngineType;
  bool get whisperAvailable => _whisperAvailable;

  void setSttEngine(SttEngineType type) {
    _sttEngineType = type;
    notifyListeners();
  }

  Future<void> _ensureServicesInitialized() async {
    if (_initialized) return;
    _initialized = true;

    // Load persisted user data
    await _prefs.init();
    _userName = _prefs.userName;
    _userAge = _prefs.userAge;
    _userLocation = _prefs.userLocation;
    _userLevel = _prefs.userLevel;
    _userLevelLabel = _prefs.userLevelLabel;
    _hasCompletedFirstSession = _prefs.hasCompletedFirstSession;
    _focusSettings = _prefs.focusSettings;

    await _stt.initialize();
    _whisperAvailable = await _whisperStt.initialize();
    debugPrint(
      'Whisper on-device available: $_whisperAvailable (model loaded: ${_whisperStt.isAvailable})',
    );
    await _tts.initialize();
  }

  /// Ensures services and persisted user data are loaded.
  /// Safe to call multiple times — only runs once.
  Future<void> ensureInitialized() => _ensureServicesInitialized();

  Future<void> initialize({String? topic}) async {
    await _ensureServicesInitialized();
    if (_messages.isNotEmpty) return;
    String starter;
    try {
      final result = await _llm.generateConversationStarter(topic: topic);
      starter = result.starter;
    } catch (_) {
      starter = "Hi! I'm Zoe. What would you like to talk about today?";
    }
    _messages.add(ChatMessage(role: MessageRole.assistant, content: starter));
    notifyListeners();
    if (_autoSpeak) {
      _isSpeaking = true;
      notifyListeners();
      await _tts.speak(starter);
      _isSpeaking = false;
      notifyListeners();
    }
  }

  /// Starts a new conversation session. Returns the LLM-generated header title
  /// (3-4 words) for the conversation screen to display.
  Future<String> startConversationSession({String? topic}) async {
    await _ensureServicesInitialized();
    _messages.clear();
    _currentTranscript = '';
    _isListening = false;
    _isMicRecognizing = false;
    _isLoading = false;
    _isSpeaking = false;
    _conversationComplete = false;
    _conversationTopic = topic?.trim().isEmpty ?? true ? null : topic;
    // Reset dirty flag: focus settings will be injected into the starter prompt.
    _focusSettingsDirty = false;
    notifyListeners();

    String starter;
    String headerTitle;
    try {
      final result = await _llm.generateConversationStarter(topic: topic);
      starter = result.starter;
      headerTitle = result.headerTitle;
    } catch (_) {
      starter = "Hi! I'm Zoe. What would you like to talk about today?";
      headerTitle = topic ?? 'Free Talk';
    }
    _messages.add(ChatMessage(role: MessageRole.assistant, content: starter));
    notifyListeners();
    if (_autoSpeak) {
      _isSpeaking = true;
      notifyListeners();
      await _tts.speak(starter);
      _isSpeaking = false;
      notifyListeners();
    }
    return headerTitle;
  }

  Future<EndResultAnalysis?> analyzeConversationEnd() {
    return _llm.analyzeConversation(
      messages: _messages,
      topic: _conversationTopic ?? 'Free Talk',
      level: _userLevel ?? 'A2',
      levelLabel: _userLevelLabel ?? 'Finding My Voice',
    );
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
      } else if (_sttEngineType == SttEngineType.continuous) {
        final sttStart = DateTime.now();
        final transcript = await _nativeStt.stopListening();
        final sttDuration = DateTime.now().difference(sttStart);
        _isListening = false;
        _isMicRecognizing = false;
        _currentTranscript = '';
        notifyListeners();
        if (transcript.isNotEmpty) {
          await sendMessage(transcript, sttDuration: sttDuration);
        }
        _sttStartTime = null;
        notifyListeners();
        if (transcript.isNotEmpty) {
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
      } else if (_sttEngineType == SttEngineType.continuous) {
        _nativeStt.onRecognizingChanged = (isRecognizing) {
          _isMicRecognizing = isRecognizing;
          notifyListeners();
        };
        final started = await _nativeStt.startListening(
          onResult: (text, isFinal) {
            if (isFinal) {
              // Final result — auto-send
              _isListening = false;
              _isMicRecognizing = false;
              _currentTranscript = '';
              notifyListeners();
              if (text.isNotEmpty) {
                sendMessage(text);
              }
            } else {
              _currentTranscript = text;
              _lastSpeechTime = DateTime.now();
              notifyListeners();
            }
          },
          silenceMs: 8000,
          possibleSilenceMs: 5000,
        );
        if (!started) {
          debugPrint('NativeSTT: Could not start');
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
  /// We do NOT auto-submit — user must tap mic again to stop.
  void _onListeningDone() {
    if (_isListening) {
      _isListening = false;
      notifyListeners();
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
    debugPrint(
      'STT result: "${result.recognizedWords}" final=${result.finalResult}',
    );
    notifyListeners();
  }

  Future<void> sendMessage(
    String text, {
    Duration? sttDuration,
    Duration? sttSpeakingDuration,
  }) async {
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
      final turnNumber =
          _messages.where((m) => m.role == MessageRole.user).length;
      // Inject focus settings only when dirty (changed since last send).
      final focusToInject = _focusSettingsDirty ? _focusSettings : null;
      _focusSettingsDirty = false;
      final result = await _llm.sendMessage(
        _messages,
        topic: _conversationTopic,
        level: _userLevel,
        levelLabel: _userLevelLabel,
        currentTurn: turnNumber,
        focusSettings: focusToInject,
      );
      llmDuration = DateTime.now().difference(llmStart);
      final reply = result.message;

      // Add bubble immediately so it appears before TTS starts
      _messages.add(
        ChatMessage(
          role: reply.role,
          content: reply.content,
          correction: reply.correction,
        ),
      );
      notifyListeners();

      // --- TTS ---
      if (_autoSpeak) {
        _isSpeaking = true;
        notifyListeners();
        final ttsStart = DateTime.now();
        await _tts.speak(reply.content);
        ttsDuration = DateTime.now().difference(ttsStart);
        _isSpeaking = false;
      }

      // Signal conversation completion AFTER TTS finishes
      if (result.conversationComplete) {
        _conversationComplete = true;
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

      _messages.add(
        ChatMessage(
          role: MessageRole.assistant,
          content: 'Sorry, I had trouble responding. Please try again.\n($e)',
          latency: latency,
        ),
      );
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
    _continuousStt.dispose();
    _nativeStt.dispose();
    _whisperStt.dispose();
    _tts.dispose();
    super.dispose();
  }
}
