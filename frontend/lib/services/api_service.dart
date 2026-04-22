import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Central service for all calls to the Ella backend.
class ApiService {
  static String get _baseUrl {
    final envUrl = dotenv.maybeGet('BACKEND_URL');
    if (envUrl != null && envUrl.isNotEmpty && !envUrl.startsWith('http://localhost')) {
      return envUrl;
    }
    return 'https://ella-api.navgurukul.org';
  }

  static const String _keyToken = 'api_token';
  static const String _keyDeviceId = 'device_id';
  static const String _keyUserId = 'user_id';

  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();
  ApiService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Token management ────────────────────────────────────────────────────

  Future<String?> getToken() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(_keyToken);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(_keyToken, token);
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await _sharedPrefs;
    String? id = prefs.getString(_keyDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  Future<String?> getUserId() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(_keyUserId);
  }

  // ── Auth ────────────────────────────────────────────────────────────────

  Future<bool> ensureAuthenticated() async {
    final token = await getToken();
    if (token != null) return true;
    return _anonymousAuth();
  }

  Future<bool> _anonymousAuth() async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      debugPrint('🔐 Auth: calling /auth/anonymous with device_id: $deviceId');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/anonymous'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('🔐 Auth response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveToken(data['access_token'] as String);
        final prefs = await _sharedPrefs;
        await prefs.setString(_keyUserId, data['user_id'] as String);
        debugPrint('✅ Auth successful');
        return true;
      }
      debugPrint('❌ Auth failed: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Auth error: $e');
      return false;
    }
  }

  // ── HTTP helpers ────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _get(String path) async {
    return http.get(
      Uri.parse('$_baseUrl$path'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 30)}) async {
    return http.post(
      Uri.parse('$_baseUrl$path'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    ).timeout(timeout);
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) async {
    return http.put(
      Uri.parse('$_baseUrl$path'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
  }

  // ── Users ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final response = await _get('/users/me');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? age,
    String? location,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (age != null) body['age'] = age;
      if (location != null) body['location'] = location;
      if (body.isEmpty) return true;
      final response = await _put('/users/me', body);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Placements ──────────────────────────────────────────────────────────

  Future<bool> savePlacement({
    required String level,
    required String levelLabel,
    required String highlight,
    List<Map<String, String>>? transcript,
  }) async {
    try {
      final response = await _post('/placements', {
        'level': level,
        'level_label': levelLabel,
        'highlight': highlight,
        if (transcript != null) 'transcript_json': transcript,
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getLatestPlacement() async {
    try {
      final response = await _get('/placements/latest');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Conversations ───────────────────────────────────────────────────────

  /// Create a new conversation session. Returns conversation id or null.
  Future<String?> createConversation({String? topic}) async {
    try {
      debugPrint('📡 Creating conversation on backend...');
      final response = await _post('/conversations', {
        if (topic != null) 'topic': topic,
      });
      debugPrint('📡 Create conversation response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as String?;
      }
      debugPrint('❌ Create conversation failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ Create conversation error: $e');
      return null;
    }
  }

  /// Mark a conversation as complete.
  Future<bool> completeConversation(String conversationId,
      {int? durationSeconds, String? sessionType}) async {
    try {
      final response = await _put('/conversations/$conversationId/complete', {
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
        if (sessionType != null) 'session_type': sessionType,
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Store a single message in a conversation.
  Future<bool> storeMessage({
    required String conversationId,
    required String role,
    required String content,
    String? correction,
    int? sttDurationMs,
    int? llmDurationMs,
    int? ttsDurationMs,
    int? turnNumber,
  }) async {
    try {
      final response = await _post(
        '/conversations/$conversationId/messages',
        {
          'role': role,
          'content': content,
          if (correction != null) 'correction': correction,
          if (sttDurationMs != null) 'stt_duration_ms': sttDurationMs,
          if (llmDurationMs != null) 'llm_duration_ms': llmDurationMs,
          if (ttsDurationMs != null) 'tts_duration_ms': ttsDurationMs,
          if (turnNumber != null) 'turn_number': turnNumber,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch all messages for a conversation.
  Future<List<Map<String, dynamic>>?> getMessages(String conversationId) async {
    try {
      final response = await _get('/conversations/$conversationId/messages');
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// List all conversations for the current user.
  Future<List<Map<String, dynamic>>?> listConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _get('/conversations?limit=$limit&offset=$offset');
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── LLM Proxy ───────────────────────────────────────────────────────────

  /// Get a conversation starter from the backend (keeps API key server-side).
  Future<Map<String, dynamic>?> getConversationStarter({String? topic}) async {
    try {
      final response = await _post(
        '/llm/conversation-starter',
        {if (topic != null) 'topic': topic},
        timeout: const Duration(seconds: 30),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Send a conversation turn through the backend LLM proxy.
  Future<Map<String, dynamic>?> sendConversationTurn({
    required String conversationId,
    required List<Map<String, String>> messages,
    String? topic,
    String level = 'A2',
    String levelLabel = 'Finding My Voice',
    int currentTurn = 1,
    String grammarFocus = 'Catch All',
    String vocabFocus = 'Occasional',
    String fluencyFocus = 'After Chat',
  }) async {
    try {
      final response = await _post(
        '/llm/conversation-turn',
        {
          'conversation_id': conversationId,
          'messages': messages,
          if (topic != null) 'topic': topic,
          'level': level,
          'level_label': levelLabel,
          'current_turn': currentTurn,
          'grammar_focus': grammarFocus,
          'vocab_focus': vocabFocus,
          'fluency_focus': fluencyFocus,
        },
        timeout: const Duration(seconds: 30),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Send a placement turn through the backend LLM proxy.
  Future<Map<String, dynamic>?> sendPlacementTurn({
    required List<Map<String, String>> messages,
  }) async {
    try {
      final response = await _post(
        '/llm/placement-turn',
        {'messages': messages},
        timeout: const Duration(seconds: 30),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Request session analysis through the backend LLM proxy.
  Future<Map<String, dynamic>?> getSessionAnalysis({
    required String conversationId,
    required List<Map<String, String>> messages,
    String topic = 'Free Talk',
    String level = 'A2',
    String levelLabel = 'Finding My Voice',
  }) async {
    try {
      final response = await _post(
        '/llm/session-analysis',
        {
          'conversation_id': conversationId,
          'messages': messages,
          'topic': topic,
          'level': level,
          'level_label': levelLabel,
        },
        timeout: const Duration(seconds: 45),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Progress ─────────────────────────────────────────────────────────────

  /// Get the user's progress summary.
  Future<Map<String, dynamic>?> getProgressSummary() async {
    try {
      final response = await _get('/progress/summary');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Health ──────────────────────────────────────────────────────────────

  Future<bool> isReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
