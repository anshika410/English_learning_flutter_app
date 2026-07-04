// HTTP client for the llm-proxy Supabase Edge Function.
// The proxy holds the DeepSeek API key server-side — the app never sees it.
// Two roles:
//   conv  → Zoe's next spoken turn (plain text)
//   judge → SkillScore list (strict JSON)

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/child_memory.dart';

class _LearnerProfile {
  final String desc;
  const _LearnerProfile(this.desc);
}

const Map<String, _LearnerProfile> _learnerProfiles = {
  'A1': _LearnerProfile(
    'a beginner who speaks in very short, broken sentences, sometimes one word, with mistakes and occasional Hinglish',
  ),
  'A2': _LearnerProfile(
    'an elementary learner managing 2-3 simple sentences with errors',
  ),
  'B1': _LearnerProfile('a B1 learner, fairly fluent with occasional mistakes'),
  'B2': _LearnerProfile('a B2 learner, fluent with minor errors'),
  'C1': _LearnerProfile('a C1 learner, very fluent and confident'),
  'C2': _LearnerProfile('a C2 learner, near-native fluency'),
};

class LlmService {
  final String
  _proxyUrl; // e.g. https://<project>.supabase.co/functions/v1/llm-proxy
  final String _anonKey;

  LlmService({required String proxyUrl, required String anonKey})
    : _proxyUrl = proxyUrl,
      _anonKey = anonKey;

  // ── conv ──────────────────────────────────────────────────────────────────
  // Returns Zoe's next spoken line.
  Future<String> conv(String prompt) async {
    final body = jsonEncode({'role': 'conv', 'prompt': prompt});
    final response = await http
        .post(Uri.parse(_proxyUrl), headers: _headers(), body: body)
        .timeout(const Duration(seconds: 30));

    _checkStatus(response, 'conv');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['text'] as String? ?? '').trim();
  }

  // ── mockLearner ───────────────────────────────────────────────────────────
  // Simulates a learner reply for auto mode. Uses the same conv proxy with a
  // role-play prompt — matches the simulator's mockKidLLM exactly.
  Future<String> mockLearner({
    required List<ConvMessage> history,
    required String level,
  }) async {
    final profile = _learnerProfiles[level] ?? _learnerProfiles['A1']!;
    final convo = history
        .where((m) => m.role != 'sys')
        .map((m) => '${m.role == 'zoe' ? 'Zoe' : 'Me'}: ${m.text}')
        .join('\n');
    final lastZoe = history.lastWhere(
      (m) => m.role == 'zoe',
      orElse: () => const ConvMessage(role: 'zoe', text: '(opening)'),
    );
    final prompt =
        'You are role-playing a LANGUAGE LEARNER (not the tutor). You are '
        '${profile.desc}. Reply ONLY as the learner — short, imperfect, '
        'realistic, with natural mistakes for your level. Do not explain.\n\n'
        'Conversation:\n$convo\n\n'
        'Tutor just said: "${lastZoe.text}"\n'
        'Your short learner reply:';

    final body = jsonEncode({'role': 'conv', 'prompt': prompt});
    final response = await http
        .post(Uri.parse(_proxyUrl), headers: _headers(), body: body)
        .timeout(const Duration(seconds: 30));
    _checkStatus(response, 'mockLearner');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = (data['text'] as String? ?? '').trim();
    return raw.replaceFirst(
      RegExp(r'^(Me:|Learner:)\s*', caseSensitive: false),
      '',
    );
  }

  // ── judge ─────────────────────────────────────────────────────────────────
  // Sends the judge prompt and parses the strict JSON response into SkillScores.
  Future<List<SkillScore>> judge(String prompt) async {
    final body = jsonEncode({'role': 'judge', 'prompt': prompt});
    final response = await http
        .post(Uri.parse(_proxyUrl), headers: _headers(), body: body)
        .timeout(const Duration(seconds: 45));

    _checkStatus(response, 'judge');
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // The proxy echoes the model's JSON; parse the `scores` array.
    final raw = data['scores'] as List?;
    if (raw == null) throw LlmException('judge: missing "scores" in response');

    return raw
        .map((e) => SkillScore.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────────

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_anonKey',
  };

  void _checkStatus(http.Response r, String role) {
    if (r.statusCode != 200) {
      throw LlmException('$role HTTP ${r.statusCode}: ${r.body}');
    }
  }
}

class LlmException implements Exception {
  final String message;
  LlmException(this.message);
  @override
  String toString() => 'LlmException: $message';
}
