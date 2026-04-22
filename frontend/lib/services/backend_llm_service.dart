import 'dart:convert';
import '../models/chat_message.dart';
import '../models/end_result_analysis.dart';
import '../models/focus_settings.dart';
import '../models/placement_result.dart';
import 'api_service.dart';

/// LLM service that routes all calls through the backend proxy.
/// Keeps API keys server-side — no keys needed in the app.
class BackendLlmService {
  final ApiService _api = ApiService.instance;

  // ── Conversation starter ─────────────────────────────────────────────────

  Future<({String starter, String headerTitle})?> generateConversationStarter({
    String? topic,
  }) async {
    final data = await _api.getConversationStarter(topic: topic);
    if (data == null) return null;
    return (
      starter: data['starter'] as String? ?? '',
      headerTitle: data['header_title'] as String? ?? topic ?? 'Free Talk',
    );
  }

  // ── Conversation turn ────────────────────────────────────────────────────

  Future<({String reply, String? correction, bool conversationComplete})?> sendConversationTurn({
    required String conversationId,
    required List<ChatMessage> history,
    String? topic,
    String level = 'A2',
    String levelLabel = 'Finding My Voice',
    int currentTurn = 1,
    FocusSettings focusSettings = const FocusSettings.defaults(),
  }) async {
    final messages = history
        .where((m) => m.role != MessageRole.system)
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    final data = await _api.sendConversationTurn(
      conversationId: conversationId,
      messages: messages,
      topic: topic,
      level: level,
      levelLabel: levelLabel,
      currentTurn: currentTurn,
      grammarFocus: focusSettings.grammar.label,
      vocabFocus: focusSettings.vocabulary.label,
      fluencyFocus: focusSettings.fluency.label,
    );

    if (data == null) return null;
    return (
      reply: data['reply'] as String? ?? '',
      correction: data['correction'] as String?,
      conversationComplete: data['conversation_complete'] as bool? ?? false,
    );
  }

  // ── Placement turn ───────────────────────────────────────────────────────

  Future<PlacementMessageResult?> sendPlacementTurn({
    required List<Map<String, String>> messages,
  }) async {
    final data = await _api.sendPlacementTurn(messages: messages);
    if (data == null) return null;

    final isComplete = data['is_complete'] as bool? ?? false;
    if (isComplete) {
      return PlacementMessageResult.complete(
        name: data['name'] as String?,
        age: data['age'] as String?,
        location: data['location'] as String?,
        assessedLevel: data['assessed_level'] as String?,
        confidence: data['confidence'] as String?,
      );
    }
    final reply = data['reply'] as String? ?? '';
    return PlacementMessageResult.reply(reply);
  }

  // ── Session analysis ─────────────────────────────────────────────────────

  Future<EndResultAnalysis?> analyzeConversation({
    required String conversationId,
    required List<ChatMessage> messages,
    required String topic,
    required String level,
    required String levelLabel,
  }) async {
    final msgList = messages
        .where((m) => m.role != MessageRole.system)
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    final data = await _api.getSessionAnalysis(
      conversationId: conversationId,
      messages: msgList,
      topic: topic,
      level: level,
      levelLabel: levelLabel,
    );

    if (data == null) return null;

    try {
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
    } catch (_) {
      return null;
    }
  }
}

/// Re-export PlacementMessageResult so callers don't need to import llm_service.dart
class PlacementMessageResult {
  final String? reply;
  final bool isComplete;
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
  })  : reply = null,
        isComplete = true;
}
