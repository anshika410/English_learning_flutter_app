import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/placement_result.dart';

enum LlmProvider { gemini }

class LlmProviderConfig {
  final String name;
  final String apiKey;
  final String baseUrl;
  final String model;

  const LlmProviderConfig({
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  bool get isConfigured => apiKey.isNotEmpty && !apiKey.contains('your_');
}

class PlacementTurnDecision {
  final bool continuePlacement;
  final String nextQuestion;
  final String? reason;

  const PlacementTurnDecision({
    required this.continuePlacement,
    required this.nextQuestion,
    this.reason,
  });
}

class LlmService {
  final LlmProviderConfig _geminiConfig;

  LlmProvider get activeProvider => LlmProvider.gemini;
  LlmProviderConfig get activeConfig => _geminiConfig;
  List<LlmProvider> get availableProviders =>
      _geminiConfig.isConfigured ? [LlmProvider.gemini] : const [];

  LlmService()
    : _geminiConfig = LlmProviderConfig(
        name: 'Gemini',
        apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        baseUrl:
            dotenv.env['GEMINI_BASE_URL'] ??
            'https://generativelanguage.googleapis.com/v1beta',
        model: dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.0-flash',
      );

  void setProvider(LlmProvider provider) {
    // Gemini is intentionally locked as the only provider.
  }

  static const _conversationSystemPrompt = '''
You are Zoe, a warm and practical English-speaking coach for Indian learners.
Keep the conversation organic and helpful, not robotic.

Behavior:
- Reply in 1-3 natural sentences.
- Ask a follow-up question when it helps keep the flow.
- Give correction only when needed, briefly and kindly.
- Avoid repeating the same coaching line every turn.

Output format:
REPLY: <natural conversational reply>
CORRECTION: <short correction or empty>
''';

  static const _starterPrompt = '''
You are Zoe. Write a short first message (1-2 sentences) that starts a friendly
English conversation. Keep it natural, encouraging, and age-appropriate.
''';

  static const _placementTurnPrompt = '''
You are running a CEFR placement conversation.
You must decide whether to continue asking questions or stop and score.

Return ONLY valid JSON:
{
  "continue_placement": true,
  "next_question": "one concise question",
  "reason": "brief reason"
}

Rules:
- Ask one question at a time.
- Keep questions clear and conversational.
- Target enough evidence for CEFR in ~5-8 user responses.
- If there is enough evidence and user_responses >= min_turns, set continue_placement=false.
- If user_responses < min_turns, continue_placement must be true.
- If user_responses >= max_turns, continue_placement must be false.
- next_question should be empty only when continue_placement is false.
''';

  static const _placementScorePrompt = '''
You are evaluating spoken-English proficiency for CEFR placement.
Given the transcript, output ONLY valid JSON with this schema:
{
  "cefr_level": "A1|A2|B1|B2|C2",
  "level_label": "short learner-facing label",
  "highlight": "one concise positive highlight sentence",
  "confidence": 0.0
}

Rules:
- confidence must be between 0.0 and 1.0.
- highlight must be specific to the transcript.
- Output JSON only, no markdown or extra text.
''';

  Future<String> generateConversationStarter({String? topic}) async {
    final topicLine = topic == null || topic.trim().isEmpty
        ? 'Topic: free conversation.'
        : 'Topic: $topic. Start specifically with this topic.';
    try {
      final text = await _sendGeminiRaw(
        systemPrompt: _starterPrompt,
        userPrompt: topicLine,
        maxOutputTokens: 120,
        temperature: 0.8,
      );
      return text.trim();
    } catch (_) {
      if (topic == null || topic.trim().isEmpty) {
        return "Hi! I'm Zoe. What would you like to talk about today?";
      }
      return "Hi! I'm Zoe. Let's talk about $topic. What's your first thought on it?";
    }
  }

  Future<ChatMessage> sendMessage(
    List<ChatMessage> history, {
    String? topicContext,
  }) async {
    final conversation = history
        .where((m) => m.role != MessageRole.system)
        .map(
          (m) =>
              '${m.role == MessageRole.user ? "USER" : "ELLA"}: ${m.content}',
        )
        .join('\n');
    final userPrompt =
        '''
${topicContext == null || topicContext.trim().isEmpty ? '' : 'Topic context: $topicContext'}
Conversation so far:
$conversation
''';
    final text = await _sendGeminiRaw(
      systemPrompt: _conversationSystemPrompt,
      userPrompt: userPrompt,
      maxOutputTokens: 260,
      temperature: 0.75,
    );
    return _parseTutorResponse(text);
  }

  Future<PlacementTurnDecision> nextPlacementTurn({
    required List<ChatMessage> history,
    required int userResponses,
    int minTurns = 5,
    int maxTurns = 8,
  }) async {
    if (userResponses >= maxTurns) {
      return const PlacementTurnDecision(
        continuePlacement: false,
        nextQuestion: '',
        reason: 'Reached max turns',
      );
    }

    final transcript = history
        .where(
          (m) => m.role == MessageRole.user || m.role == MessageRole.assistant,
        )
        .map(
          (m) =>
              '${m.role == MessageRole.user ? "USER" : "ELLA"}: ${m.content}',
        )
        .join('\n');

    final userPrompt =
        '''
min_turns: $minTurns
max_turns: $maxTurns
user_responses: $userResponses
transcript:
$transcript
''';

    try {
      final raw = await _sendGeminiRaw(
        systemPrompt: _placementTurnPrompt,
        userPrompt: userPrompt,
        maxOutputTokens: 220,
        temperature: 0.5,
      );
      final data = jsonDecode(_extractJsonObject(raw)) as Map<String, dynamic>;
      bool shouldContinue = data['continue_placement'] == true;
      final question = (data['next_question'] as String? ?? '').trim();
      final reason = (data['reason'] as String?)?.trim();

      if (userResponses < minTurns) {
        shouldContinue = true;
      }
      if (userResponses >= maxTurns) {
        shouldContinue = false;
      }

      return PlacementTurnDecision(
        continuePlacement: shouldContinue,
        nextQuestion: shouldContinue
            ? (question.isNotEmpty
                  ? question
                  : 'Can you tell me more about your daily routine in English?')
            : '',
        reason: reason,
      );
    } catch (_) {
      final fallbackContinue = userResponses < minTurns;
      return PlacementTurnDecision(
        continuePlacement: fallbackContinue,
        nextQuestion: fallbackContinue
            ? 'Can you describe a recent experience and how you felt about it?'
            : '',
        reason: 'Fallback due to parse/API issue',
      );
    }
  }

  Future<PlacementResult> evaluatePlacement(List<ChatMessage> history) async {
    final transcript = history
        .where(
          (m) => m.role == MessageRole.user || m.role == MessageRole.assistant,
        )
        .map(
          (m) =>
              '${m.role == MessageRole.user ? "USER" : "ELLA"}: ${m.content}',
        )
        .join('\n');

    final rawText = await _sendGeminiRaw(
      systemPrompt: _placementScorePrompt,
      userPrompt: transcript,
      maxOutputTokens: 240,
      temperature: 0.3,
    );

    final data =
        jsonDecode(_extractJsonObject(rawText)) as Map<String, dynamic>;

    final level = (data['cefr_level'] as String? ?? 'A2').toUpperCase();
    final labels = <String, String>{
      'A1': 'Starting Out',
      'A2': 'Finding My Voice',
      'B1': 'Speaking with Confidence',
      'B2': 'Expressing with Clarity',
      'C2': 'Near-Native Flow',
    };

    final parsedConfidence = data['confidence'];
    double? confidence;
    if (parsedConfidence is num) confidence = parsedConfidence.toDouble();

    return PlacementResult(
      cefrLevel: labels.containsKey(level) ? level : 'A2',
      levelLabel: data['level_label'] as String? ?? labels[level],
      highlight:
          data['highlight'] as String? ??
          'You communicated clearly and stayed engaged through the conversation.',
      confidence: confidence,
    );
  }

  Future<String> _sendGeminiRaw({
    required String systemPrompt,
    required String userPrompt,
    required int maxOutputTokens,
    required double temperature,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${_geminiConfig.baseUrl}/models/${_geminiConfig.model}:generateContent',
      ),
      headers: {
        'Content-Type': 'application/json',
        'X-goog-api-key': _geminiConfig.apiKey,
      },
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': userPrompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxOutputTokens,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw Exception('Gemini API error: empty candidates');
    }
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    if (parts.isEmpty) {
      throw Exception('Gemini API error: empty parts');
    }
    final text = parts.first['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini API error: empty text');
    }
    return text.trim();
  }

  ChatMessage _parseTutorResponse(String text) {
    String mainReply = text.trim();
    String? correction;

    final replyMatch = RegExp(
      r'REPLY:\s*(.*?)(?:\nCORRECTION:|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    final correctionMatch = RegExp(
      r'CORRECTION:\s*(.*)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (replyMatch != null) {
      mainReply = (replyMatch.group(1) ?? '').trim();
    }
    if (correctionMatch != null) {
      final parsed = (correctionMatch.group(1) ?? '').trim();
      correction = parsed.isEmpty ? null : parsed;
    }

    if (mainReply.isEmpty) {
      mainReply = text.trim();
    }

    return ChatMessage(
      role: MessageRole.assistant,
      content: mainReply,
      correction: correction,
    );
  }

  String _extractJsonObject(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;

    final fenced = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
    ).firstMatch(trimmed);
    if (fenced != null) {
      final candidate = fenced.group(1)?.trim();
      if (candidate != null &&
          candidate.startsWith('{') &&
          candidate.endsWith('}')) {
        return candidate;
      }
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    throw Exception('Could not parse JSON from model output');
  }
}
