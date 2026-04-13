import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/end_result_analysis.dart';
import '../models/focus_settings.dart';
import '../models/placement_result.dart';

enum LlmProvider { deepseek }

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

// Represents one turn result from the placement conversation
class PlacementMessageResult {
  /// Zoe's reply text (null when isComplete is true)
  final String? reply;
  final bool isComplete;
  // Only populated when isComplete is true
  final String? name;
  final String? age;
  final String? location;
  final String? assessedLevel;
  final String? confidence;
  final String? notes;

  const PlacementMessageResult.reply(String text)
    : reply = text,
      isComplete = false,
      name = null,
      age = null,
      location = null,
      assessedLevel = null,
      confidence = null,
      notes = null;

  const PlacementMessageResult.complete({
    this.name,
    this.age,
    this.location,
    this.assessedLevel,
    this.confidence,
    this.notes,
  }) : reply = null,
       isComplete = true;
}

class ConversationTurnResult {
  final ChatMessage message;
  final bool conversationComplete;
  const ConversationTurnResult({
    required this.message,
    required this.conversationComplete,
  });
}

class LlmService {
  final LlmProviderConfig _config;
  String? _cachedPlacementPrompt;
  String? _cachedConversationPrompt;

  LlmProvider get activeProvider => LlmProvider.deepseek;
  LlmProviderConfig get activeConfig => _config;
  List<LlmProvider> get availableProviders =>
      _config.isConfigured ? [LlmProvider.deepseek] : const [];

  LlmService()
    : _config = LlmProviderConfig(
        name: 'DeepSeek',
        apiKey: dotenv.env['DEEPSEEK_API_KEY'] ?? '',
        baseUrl:
            dotenv.env['DEEPSEEK_BASE_URL'] ??
            'https://api.deepseek.com/v1',
        model: dotenv.env['DEEPSEEK_MODEL'] ?? 'deepseek-chat',
      );

  void setProvider(LlmProvider provider) {
    // DeepSeek is the only provider.
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

  /// Returns both the opening starter message and a short header title.
  Future<({String starter, String headerTitle})> generateConversationStarter({
    String? topic,
  }) async {
    final topicLine = topic == null || topic.trim().isEmpty
        ? 'Topic: free conversation.'
        : 'Topic: $topic. Start specifically with this topic.';
    final prompt = '''
$_starterPrompt

After the starter, on a new line output:
TITLE: <3-4 word header for this conversation, no punctuation>
''';
    try {
      final text = await _sendChatCompletion(
        messages: [
          {'role': 'system', 'content': prompt},
          {'role': 'user', 'content': topicLine},
        ],
        maxTokens: 160,
        temperature: 0.8,
      );
      final titleMatch = RegExp(
        r'TITLE:\s*(.+)',
        caseSensitive: false,
      ).firstMatch(text);
      final headerTitle = titleMatch != null
          ? titleMatch.group(1)!.trim()
          : (topic ?? 'Free Talk');
      final starter = text
          .replaceAll(RegExp(r'TITLE:.*', caseSensitive: false), '')
          .trim();
      return (starter: starter.isEmpty ? text.trim() : starter, headerTitle: headerTitle);
    } catch (_) {
      final fallbackStarter = topic == null || topic.trim().isEmpty
          ? "Hi! I'm Zoe. What would you like to talk about today?"
          : "Hi! I'm Zoe. Let's talk about $topic. What's your first thought on it?";
      return (starter: fallbackStarter, headerTitle: topic ?? 'Free Talk');
    }
  }

  /// Sends the next conversation turn using the filled conversation-prompt.md template.
  Future<ConversationTurnResult> sendMessage(
    List<ChatMessage> history, {
    String? topic,
    String? level,
    String? levelLabel,
    int currentTurn = 1,
    FocusSettings? focusSettings,
  }) async {
    final systemPrompt = await _loadConversationPrompt(
      topic: topic ?? 'Free conversation',
      level: level ?? 'A2',
      levelLabel: levelLabel ?? 'Finding My Voice',
      currentTurn: currentTurn,
      focusSettings: focusSettings ?? const FocusSettings.defaults(),
    );

    final apiMessages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history
          .where((m) => m.role != MessageRole.system)
          .map((m) => {
                'role': m.role == MessageRole.user ? 'user' : 'assistant',
                'content': m.content,
              }),
    ];

    final response = await _sendChatCompletion(
      messages: apiMessages,
      maxTokens: 280,
      temperature: 0.75,
    );

    // Check for conversation_complete JSON signal
    bool complete = false;
    String replyText = response;
    final jsonMatch = RegExp(
      r'\{[^}]*"conversation_complete"\s*:\s*true[^}]*\}',
    ).firstMatch(response);
    if (jsonMatch != null) {
      complete = true;
      replyText = response.substring(0, jsonMatch.start).trim();
    }

    final message = _parseTutorResponse(replyText.isEmpty ? response : replyText);
    return ConversationTurnResult(message: message, conversationComplete: complete);
  }

  Future<String> _loadConversationPrompt({
    required String topic,
    required String level,
    required String levelLabel,
    required int currentTurn,
    required FocusSettings focusSettings,
  }) async {
    _cachedConversationPrompt ??= await rootBundle.loadString(
      'assets/prompts/conversation-prompt.md',
    );
    final levelInstructions = _levelInstructions(level);
    return _cachedConversationPrompt!
        .replaceAll('{{TOPIC}}', topic)
        .replaceAll('{{LEVEL}}', level)
        .replaceAll('{{LEVEL_LABEL}}', levelLabel)
        .replaceAll('{{CURRENT_TURN}}', '$currentTurn')
        .replaceAll('{{LEVEL_INSTRUCTIONS}}', levelInstructions)
        .replaceAll('{{GRAMMAR_SETTING}}', focusSettings.grammar.label)
        .replaceAll('{{VOCABULARY_SETTING}}', focusSettings.vocabulary.label)
        .replaceAll('{{FLUENCY_SETTING}}', focusSettings.fluency.label);
  }

  String _levelInstructions(String level) {
    switch (level.toUpperCase()) {
      case 'A1':
        return 'Accept any attempt as a valid turn. Never require full sentences. Celebrate every response.\nAsk only personal, familiar questions (family, food, daily routine, things they like).\nSpeak at 40–60 wpm pace equivalent. Use only present simple and common vocabulary.';
      case 'A2':
        return 'Use salient recasts — model the correct form naturally in your reply.\nAsk about past events and simple opinions. Introduce "Have you ever…?" questions.\nShow filler words awareness only in post-session (not during conversation).';
      case 'B1':
        return 'Use metalinguistic nudges — name the error category and wait before correcting.\nExample: "Almost — which tense would we use for something finished in the past?"\nPush for 60-second responses by asking follow-up "tell me more" questions.\nOffer vocabulary alternatives mid-conversation (maximum 2 per session).';
      case 'B2':
        return 'Apply explicit correction when grammar_setting permits. State error, correct form, brief reason.\nPush for 4-part argument: claim → reason → evidence → concession.\nFlag register mismatches. Offer 2–3 precision vocabulary alternatives.';
      case 'C1':
        return 'Operate in peer mode. Suggestions, not corrections.\nIntroduce stylistic options: "You could also say \'pivotal\' here — it implies a turning point."\nExpect idiomatic expression and fluent reformulation.';
      default:
        return 'Use salient recasts — model the correct form naturally in your reply.';
    }
  }

  Future<EndResultAnalysis?> analyzeConversation({
    required List<ChatMessage> messages,
    required String topic,
    required String level,
    required String levelLabel,
  }) async {
    final template = await rootBundle.loadString(
      'assets/prompts/end-result-prompt.md',
    );
    final transcript = messages
        .where((m) => m.role != MessageRole.system)
        .map((m) => '${m.role == MessageRole.user ? "STUDENT" : "ZOE"}: ${m.content}')
        .join('\n');

    final systemPrompt = template
        .replaceAll('{{LEVEL}}', level)
        .replaceAll('{{LEVEL_LABEL}}', levelLabel)
        .replaceAll('{{TOPIC}}', topic)
        .replaceAll('{{FULL_TRANSCRIPT}}', transcript);

    try {
      final raw = await _sendChatCompletion(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': 'Analyze the transcript and return the JSON report.'},
        ],
        maxTokens: 1200,
        temperature: 0.4,
      );
      final jsonStr = _extractJsonObject(raw);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final bestMoment = data['best_moment'] as Map<String, dynamic>? ?? {};
      final courage = data['courage_or_motivation'] as Map<String, dynamic>? ?? {};
      final tryNext = data['try_next_time'] as Map<String, dynamic>? ?? {};
      final notesRaw = data['transcript_notes'] as List<dynamic>? ?? [];

      final notes = notesRaw.map((n) {
        final m = n as Map<String, dynamic>;
        return EndResultTranscriptNote(
          speaker: m['speaker'] as String? ?? 'zoe',
          text: m['text'] as String? ?? '',
          note: m['note'] as String?,
        );
      }).toList();

      return EndResultAnalysis(
        overall: data['overall'] as String? ?? 'okay',
        bestMomentQuote: bestMoment['quote'] as String? ?? '',
        bestMomentNote: bestMoment['note'] as String? ?? '',
        courageOrMotivationType: courage['type'] as String? ?? 'motivation',
        courageOrMotivationContent: courage['content'] as String? ?? '',
        tryNextTimeSkill: tryNext['skill'] as String? ?? '',
        tryNextTimeExample: tryNext['example'] as String? ?? '',
        transcriptNotes: notes,
      );
    } catch (e) {
      return null;
    }
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
      final raw = await _sendChatCompletion(
        messages: [
          {'role': 'system', 'content': _placementTurnPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        maxTokens: 220,
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

    final rawText = await _sendChatCompletion(
      messages: [
        {'role': 'system', 'content': _placementScorePrompt},
        {'role': 'user', 'content': transcript},
      ],
      maxTokens: 240,
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

  Future<String> _loadPlacementPrompt() async {
    _cachedPlacementPrompt ??= await rootBundle.loadString(
      'assets/prompts/placement-check-prompt.md',
    );
    return _cachedPlacementPrompt!;
  }

  /// Sends the placement conversation history to the LLM using the
  /// placement-check-prompt.md as the system prompt.
  ///
  /// [messages] is a list of {role: 'user'|'model', content: '...'} maps
  /// representing the conversation so far (excluding the system prompt).
  Future<PlacementMessageResult> sendPlacementMessage(
    List<Map<String, String>> messages,
  ) async {
    final systemPrompt = await _loadPlacementPrompt();

    final apiMessages = [
      {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => {
            'role': m['role'] == 'user' ? 'user' : 'assistant',
            'content': m['content'] ?? '',
          }),
    ];

    final text = await _sendChatCompletion(
      messages: apiMessages,
      maxTokens: 200,
      temperature: 0.7,
    );

    // Check if it's a REPLY: prefixed conversational turn
    final replyMatch = RegExp(
      r'REPLY:\s*(.*)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (replyMatch != null) {
      final reply = (replyMatch.group(1) ?? '').trim();
      return PlacementMessageResult.reply(reply.isNotEmpty ? reply : text);
    }

    // Otherwise attempt to parse as final JSON assessment
    try {
      final jsonStr = _extractJsonObject(text);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (json.containsKey('assessed_level')) {
        return PlacementMessageResult.complete(
          name: json['name'] as String?,
          age: json['age'] as String?,
          location: json['location'] as String?,
          assessedLevel: json['assessed_level'] as String?,
          confidence: json['confidence'] as String?,
          notes: json['notes'] as String?,
        );
      }
    } catch (_) {
      // Not valid JSON — fall through and treat as a plain reply
    }

    // Fallback: treat entire response as a reply
    return PlacementMessageResult.reply(text);
  }

  /// Generic OpenAI-compatible chat completion (works with DeepSeek).
  Future<String> _sendChatCompletion({
    required List<Map<String, String>> messages,
    required int maxTokens,
    required double temperature,
  }) async {
    final response = await http.post(
      Uri.parse('${_config.baseUrl}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config.apiKey}',
      },
      body: jsonEncode({
        'model': _config.model,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'LLM API error: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) throw Exception('LLM API error: empty choices');
    final message = choices.first['message'] as Map<String, dynamic>?;
    final text = message?['content'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw Exception('LLM API error: empty content');
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
