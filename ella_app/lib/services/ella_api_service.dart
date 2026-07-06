import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/child_memory.dart';
import '../models/garden.dart';
import '../models/placement.dart';
import '../models/session.dart';

class EllaApiException implements Exception {
  final String message;
  const EllaApiException(this.message);

  @override
  String toString() => 'EllaApiException: $message';
}

class ConversationTurnApiResponse {
  final List<Map<String, dynamic>> transcript;
  final bool conversationComplete;

  const ConversationTurnApiResponse({
    required this.transcript,
    required this.conversationComplete,
  });

  String? get latestAssistantText {
    for (final message in transcript.reversed) {
      final speaker = (message['speaker'] ?? message['role'] ?? '').toString();
      if (speaker == 'assistant' || speaker == 'zoe') {
        return (message['text'] ?? message['content'] ?? '').toString();
      }
    }
    return null;
  }
}

class SessionAnalysisApiResult {
  final List<SkillScore> scores;
  final List<StateChange> changes;
  final List<String> aimedAt;
  final List<String> hitTargets;
  final Map<String, dynamic> raw;

  const SessionAnalysisApiResult({
    required this.scores,
    required this.changes,
    required this.aimedAt,
    required this.hitTargets,
    required this.raw,
  });
}

class EllaApiService {
  static const _tokenKey = 'ella_api_access_token';
  static const _userIdKey = 'ella_api_user_id';
  static const _deviceIdKey = 'ella_api_device_id';

  // First-run onboarding (name/age) cache. `_onboardingDoneKey` gates the
  // onboarding flow so it runs once; name/age are cached for the greeting and
  // to seed the placement flow without a network round-trip.
  static const _onboardingDoneKey = 'ella_onboarding_done';
  static const _childNameKey = 'ella_child_name';
  static const _childAgeKey = 'ella_child_age';

  final String baseUrl;
  final http.Client _client;

  EllaApiService({
    this.baseUrl = 'https://ella.navgurukul.org/api',
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveTokens(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  Future<bool> loginWithGoogle(String idToken) async {
    try {
      final data = await _request('POST', '/auth/google', auth: false, body: {'token': idToken});
      final accessToken = data['access_token'];
      final userId = data['user_id'];
      if (accessToken != null && userId != null) {
        await saveTokens(accessToken, userId);
        return true;
      }
      return false;
    } catch (e) {
      _log('Google Auth Error', e.toString());
      return false;
    }
  }

  Future<bool> requestMagicLink(String email) async {
    try {
      // Create a URL scheme for returning to the app
      String redirectUrl;
      if (kIsWeb) {
        // Use the current web origin (e.g. http://localhost:3000)
        redirectUrl = '${Uri.base.origin}/#/login'; 
      } else {
        redirectUrl = 'ella://login';
      }
      
      await _request(
        'POST', 
        '/auth/magic-link/request', 
        auth: false, 
        body: {'email': email, 'redirect_url': redirectUrl}
      );
      return true;
    } catch (e) {
      _log('Magic Link Error', e.toString());
      return false;
    }
  }

  Future<String?> getCachedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<MemoryState> getUserMemory() async {
    final data = await _request('GET', '/users/me/memory');
    return _memoryFromApi(data);
  }

  /// Garden layout for the signed-in user — GET /users/me/garden.
  Future<GardenData> getGarden() async {
    final data = await _request('GET', '/users/me/garden');
    final garden = GardenData.fromJson(data);
    // The garden renders nothing without units. If the API responded OK but we
    // parsed zero units, it's almost always a payload-key change (e.g. the
    // `steps`→`units` rename): the render silently blanks. Log the top-level
    // keys we actually received so a future rename is obvious, not a mystery.
    if (garden.steps.isEmpty) {
      debugPrint(
        '⚠️ [Garden] parsed 0 units — the garden will render blank. '
        'Response top-level keys: ${data.keys.toList()}. '
        'If the units are under a new key, update GardenData.fromJson.',
      );
    }
    if (kDebugMode) {
      debugPrint(
        '┌─[Garden] parsed level=${garden.level} '
        'label=${garden.levelLabel} theme=${garden.theme} '
        'steps=${garden.steps.length} topic=${garden.recommendedTopic}',
      );
      for (final step in garden.steps) {
        debugPrint(
          '│ step ${step.step} "${step.name}" '
          'completed=${step.isCompleted} skills=${step.skills.length}',
        );
        for (final s in step.skills) {
          debugPrint(
            '│   • ${s.id} ${s.strand.name} ${s.status.name} '
            'sightings=${s.sightings} evidence=${s.evidence.length}'
            '${s.evidence.isNotEmpty ? ' → "${s.evidence.first.quote}"' : ''}',
          );
        }
      }
      debugPrint('└────────────────────────────────────────');
    }
    return garden;
  }

  Future<void> updatePersonaMemory(Map<String, dynamic> personaMemory) async {
    await _request(
      'PUT',
      '/users/me/memory',
      body: {'persona_memory': personaMemory},
    );
  }

  /// Persist the child's profile collected during onboarding. Mirrors
  /// [updatePersonaMemory]'s PUT-to-/users/me shape.
  Future<void> updateProfile({required String name, required int age}) async {
    await _request('PUT', '/users/me', body: {'name': name, 'age': age});
  }

  // ── Onboarding cache (local) ────────────────────────────────────────────────
  // Gates the first-run onboarding flow and remembers the child's name/age for
  // the greeting + placement seeding. Stored in the same SharedPreferences this
  // service already owns for auth tokens.

  Future<({bool done, String? name, int? age})> getOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      done: prefs.getBool(_onboardingDoneKey) ?? false,
      name: prefs.getString(_childNameKey),
      age: prefs.getInt(_childAgeKey),
    );
  }

  Future<void> saveOnboarding({
    required String name,
    required int age,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_childNameKey, name);
    await prefs.setInt(_childAgeKey, age);
    await prefs.setBool(_onboardingDoneKey, true);
  }

  /// Cache just the name/age (onboarding NOT yet done) — written the moment
  /// the child answers, so a relaunch resumes at the first-sprout garden
  /// instead of re-asking name and age.
  Future<void> saveOnboardingProfile({
    required String name,
    required int age,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_childNameKey, name);
    await prefs.setInt(_childAgeKey, age);
  }

  Future<List<SessionLog>> listSessions({
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _request('GET', '/session?limit=$limit&offset=$offset');
    final rows = (data['_list'] as List? ?? const []);
    return [
      for (var i = 0; i < rows.length; i++)
        _sessionFromConversation(
          Map<String, dynamic>.from(rows[i] as Map),
          chatNumber: offset + i + 1,
        ),
    ];
  }

  Future<Map<String, dynamic>> createConversation({String? topic}) async {
    return _request(
      'POST',
      '/session',
      body: {if (topic != null && topic.isNotEmpty) 'topic': topic},
    );
  }

  Future<Map<String, dynamic>> getConversation(String sessionId) async {
    return _request('GET', '/session/$sessionId');
  }

  Future<List<Map<String, dynamic>>> getMessages(String sessionId) async {
    final data = await _request('GET', '/session/$sessionId/messages');
    return [
      for (final item in data['_list'] as List? ?? const [])
        Map<String, dynamic>.from(item as Map),
    ];
  }

  Future<Map<String, dynamic>> storeMessage({
    required String sessionId,
    required String role,
    required String content,
    int turnNumber = 0,
  }) {
    return _request(
      'POST',
      '/session/$sessionId/messages',
      body: {'role': role, 'content': content, 'turn_number': turnNumber},
    );
  }

  Future<ConversationTurnApiResponse> conversationTurn({
    required String sessionId,
    required String content,
  }) async {
    final data = await _request(
      'POST',
      '/session/$sessionId/turn',
      body: {'content': content},
    );
    return ConversationTurnApiResponse(
      transcript: [
        for (final item in data['transcript'] as List? ?? const [])
          Map<String, dynamic>.from(item as Map),
      ],
      conversationComplete: data['conversation_complete'] as bool? ?? false,
    );
  }

  /// One turn of the voice placement screening — POST /llm/placement-turn.
  /// The full running transcript is sent on every call (the endpoint is
  /// stateless); the response is either Zoe's next question or, once enough
  /// evidence is gathered, the final CEFR assessment (`is_complete: true`).
  /// [name]/[age], if known from earlier turns, are threaded back so the LLM
  /// keeps its context.
  Future<PlacementTurnResult> placementTurn({
    required List<Map<String, String>> messages,
    String? name,
    int? age,
  }) async {
    final data = await _request(
      'POST',
      '/llm/placement-turn',
      body: {
        'messages': messages,
        if (name != null && name.isNotEmpty) 'name': name,
        'age': ?age,
      },
    );
    return PlacementTurnResult.fromJson(data);
  }

  Future<String?> conversationStarter({String? topic}) async {
    final data = await _request(
      'POST',
      '/llm/conversation-starter',
      body: {if (topic != null && topic.isNotEmpty) 'topic': topic},
    );
    return data['starter'] as String?;
  }

  /// Session log snapshot — GET /session/{session_id}/session-log.
  /// The server's canonical record of a finished session (scores, state
  /// changes, transcript). Called after the judge persists the analysis.
  Future<Map<String, dynamic>> getSessionLog(String sessionId) {
    return _request('GET', '/session/$sessionId/session-log');
  }

  // The judge/session-analysis request shape (SessionAnalysisRequest):
  //   { session_id, messages[], topic, level, level_label, progression_model }
  Map<String, dynamic> _analysisRequestBody({
    required String sessionId,
    required List<ConvMessage> history,
    required String topic,
    required String level,
    required String levelLabel,
    required String progressionModel,
  }) => {
    'session_id': sessionId,
    'messages': [
      for (final m in history)
        {'role': m.role == 'zoe' ? 'assistant' : 'user', 'content': m.text},
    ],
    'topic': topic,
    'level': level,
    'level_label': levelLabel,
    'progression_model': _serverProgressionModel(progressionModel),
  };

  Future<SessionAnalysisApiResult> sessionAnalysis({
    required String sessionId,
    required List<ConvMessage> history,
    required String topic,
    required String level,
    String levelLabel = '',
    required String progressionModel,
  }) async {
    final data = await _request(
      'POST',
      '/llm/session-analysis',
      body: _analysisRequestBody(
        sessionId: sessionId,
        history: history,
        topic: topic,
        level: level,
        levelLabel: levelLabel,
        progressionModel: progressionModel,
      ),
    );
    return _analysisFromApi(data);
  }

  Future<SessionAnalysisApiResult> judge({
    required String sessionId,
    required List<ConvMessage> history,
    required String topic,
    required String level,
    String levelLabel = '',
    required String progressionModel,
  }) async {
    final data = await _request(
      'POST',
      '/llm/judge',
      body: _analysisRequestBody(
        sessionId: sessionId,
        history: history,
        topic: topic,
        level: level,
        levelLabel: levelLabel,
        progressionModel: progressionModel,
      ),
    );
    return _analysisFromApi(data);
  }

  Future<List<Map<String, dynamic>>> listPlacements() async {
    final data = await _request('GET', '/placements');
    return [
      for (final item in data['_list'] as List? ?? const [])
        Map<String, dynamic>.from(item as Map),
    ];
  }

  Future<Map<String, dynamic>?> latestPlacement() async {
    final data = await _request('GET', '/placements/latest');
    return data.isEmpty ? null : data;
  }

  Future<Map<String, dynamic>> createPlacement(Map<String, dynamic> body) {
    return _request('POST', '/placements', body: body);
  }

  Future<Map<String, dynamic>> progressSummary() {
    return _request('GET', '/progress/summary');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    bool auth = true,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    _log('REQUEST  $method $uri', body != null ? jsonEncode(body) : null);

    final Future<http.Response> request = switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body ?? {}),
      ),
      'PUT' => _client.put(uri, headers: headers, body: jsonEncode(body ?? {})),
      _ => throw EllaApiException('Unsupported method $method'),
    };
    final http.Response response;
    try {
      response = await request.timeout(const Duration(seconds: 45));
    } catch (e) {
      _log('NETWORK ERROR  $method $path', '$e');
      rethrow;
    }

    _log('RESPONSE $method $path  HTTP ${response.statusCode}', response.body);

    if (response.statusCode == 401 && auth) {
      await _clearToken();
      return _request(method, path, auth: auth, body: body);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EllaApiException(
        '$method $path HTTP ${response.statusCode}: ${response.body}',
      );
    }
    if (response.body.trim().isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is List) return {'_list': decoded};
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// Maps the app's progression-model token to what the backend expects.
  /// The app uses 'units' / 'micro-skill'; the API's session-analysis schema
  /// keys off the singular 'unit' (its default), so sending 'units' was being
  /// treated as NOT-units → micro-skill framing.
  static String _serverProgressionModel(String appModel) {
    switch (appModel) {
      case 'units':
        return 'unit';
      case 'micro-skill':
        return 'micro_skill';
      default:
        return appModel;
    }
  }

  /// Logs every request/response via `debugPrint`, so it shows in the
  /// `flutter run` console, Android logcat, and the web browser console.
  /// Debug builds only — stripped from release.
  void _log(String header, [String? payload]) {
    if (!kDebugMode) return;
    debugPrint('┌─[EllaAPI] $header');
    if (payload != null && payload.trim().isNotEmpty) {
      // Pretty-print JSON when possible; logcat truncates very long single
      // lines, so emit line-by-line.
      String pretty;
      try {
        pretty = const JsonEncoder.withIndent(
          '  ',
        ).convert(jsonDecode(payload));
      } catch (_) {
        pretty = payload;
      }
      for (final line in pretty.split('\n')) {
        debugPrint('│ $line');
      }
    }
    debugPrint('└────────────────────────────────────────');
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  static String _newDeviceId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return 'ella-flutter-$now';
  }

  static MemoryState _memoryFromApi(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? j['user_id'] as String? ?? 'api-user';
    final effort = Map<String, dynamic>.from((j['effort'] as Map?) ?? {});
    final interests = (j['interests'] as List? ?? const []).join(', ');
    return MemoryState(
      childId: id,
      level: j['level'] as String? ?? 'A1',
      hasLevel: (j['level'] as String?)?.isNotEmpty ?? false,
      owned: List<String>.from((j['owned'] as List?) ?? const []),
      emerging: List<String>.from((j['emerging'] as List?) ?? const []),
      dueNext: j['due_next'] is Map
          ? DueNext.fromJson(Map<String, dynamic>.from(j['due_next'] as Map))
          : const DueNext(),
      interests: interests,
      sightings: _intMap(j['sightings']),
      strength: _intMap(j['strength']),
      lastTopics: List<String>.from((j['last_topics'] as List?) ?? const []),
      lastTimeRecap: j['last_time_recap'] as String? ?? '',
      nextTopics: j['next_topics'] is Map
          ? NextTopics.fromJson(
              Map<String, dynamic>.from(j['next_topics'] as Map),
            )
          : NextTopics.empty,
      effortTimesSpoken: (effort['times_spoken_total'] as num?)?.toInt() ?? 0,
      updatedAfterChat: (j['updated_after_chat'] as num?)?.toInt() ?? 0,
      placement: j['placement'] is Map
          ? PlacementInfo.fromJson(
              Map<String, dynamic>.from(j['placement'] as Map),
            )
          : null,
    );
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return Map<String, int>.from(
      value.map((key, val) => MapEntry(key as String, (val as num).toInt())),
    );
  }

  static SessionLog _sessionFromConversation(
    Map<String, dynamic> j, {
    required int chatNumber,
  }) {
    return SessionLog(
      sessionId: j['session_id'] as String?,
      childId: '',
      chatNumber: chatNumber,
      level: j['level'] as String? ?? 'A1',
      progressionModel: 'units',
      turnsTotal: (j['duration_seconds'] as num?)?.toInt() ?? 0,
      topic: j['topic'] as String?,
      aimedAt: List<String>.from((j['aimed_at'] as List?) ?? const []),
    );
  }

  static SessionAnalysisApiResult _analysisFromApi(Map<String, dynamic> data) {
    return SessionAnalysisApiResult(
      scores: [
        for (final item in data['skills_evidenced'] as List? ?? const [])
          SkillScore.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      changes: [
        for (final item in data['state_changes'] as List? ?? const [])
          StateChange(
            id: (item as Map)['id'] as String,
            from: item['from'] as String,
            to: item['to'] as String,
          ),
      ],
      aimedAt: List<String>.from((data['aimed_at'] as List?) ?? const []),
      hitTargets: List<String>.from((data['hit_targets'] as List?) ?? const []),
      raw: data,
    );
  }
}
