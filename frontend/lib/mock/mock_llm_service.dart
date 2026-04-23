import '../models/chat_message.dart';
import '../models/end_result_analysis.dart';
import '../models/focus_settings.dart';
import '../services/llm_service.dart';
import '../services/llm_service_base.dart';

/// Scripted mock LLM service for testing and demos.
///
/// Runs a fixed 5-question placement (→ B1 result) and a fixed 5-turn
/// conversation (→ "good" end analysis) without any API calls.
///
/// To switch back to real API: set [kUseMockLlm] = false in mock_config.dart.
class MockLlmService implements LlmServiceBase {
  // ── Placement ────────────────────────────────────────────────────────────

  static const _placementQuestions = [
    "Hey! I'm Zoe. What's your name?",
    "Nice to meet you! How old are you?",
    "Cool! Where are you from in India?",
    "Interesting! What do you like to do in your free time?",
    "Great! Tell me about your favourite movie or TV show.",
  ];

  @override
  Future<PlacementMessageResult> sendPlacementMessage(
    List<Map<String, String>> messages, {
    String promptPath =
        'assets/prompts/placement-check-adaptive-friendly.md',
    String userName = 'there',
    String userAge = '15',
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final userTurnCount = messages.where((m) => m['role'] == 'user').length;

    if (userTurnCount < _placementQuestions.length) {
      return PlacementMessageResult.reply(
        _placementQuestions[userTurnCount],
      );
    }

    return const PlacementMessageResult.complete(
      assessedLevel: 'B1',
      confidence: '0.87',
      notes: 'Student showed solid B1 fluency across varied topics.',
    );
  }

  // ── Conversation starter ─────────────────────────────────────────────────

  @override
  Future<({String starter, String headerTitle})> generateConversationStarter({
    String? topic,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final effectiveTopic =
        (topic == null || topic.trim().isEmpty) ? 'Technology' : topic.trim();
    return (
      starter:
          "Let's talk about $effectiveTopic! Do you use your phone a lot?",
      headerTitle: effectiveTopic,
    );
  }

  // ── Conversation turns ───────────────────────────────────────────────────

  static const _conversationReplies = [
    (
      text: "That's interesting! What apps do you use the most?",
      complete: false,
    ),
    (
      text: "Cool! Do you think technology makes life better or worse?",
      complete: false,
    ),
    (
      text: "Nice point! What about social media — do you use it much?",
      complete: false,
    ),
    (
      text:
          "Interesting! How do you think technology will change in the future?",
      complete: false,
    ),
    (
      text:
          "That's a great thought! I really enjoyed our conversation today. You did brilliantly!",
      complete: true,
    ),
  ];

  @override
  Future<ConversationTurnResult> sendMessage(
    List<ChatMessage> history, {
    String? topic,
    String? level,
    String? levelLabel,
    int currentTurn = 1,
    FocusSettings? focusSettings,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    // ChatProvider appends the user message before calling sendMessage,
    // so user turn count reflects the message just sent.
    final userTurnCount =
        history.where((m) => m.role == MessageRole.user).length;
    final index =
        (userTurnCount - 1).clamp(0, _conversationReplies.length - 1);
    final scripted = _conversationReplies[index];

    final message = ChatMessage(
      role: MessageRole.assistant,
      content: scripted.text,
    );

    return ConversationTurnResult(
      message: message,
      conversationComplete: scripted.complete,
    );
  }

  // ── End analysis ─────────────────────────────────────────────────────────

  @override
  Future<EndResultAnalysis?> analyzeConversation({
    required List<ChatMessage> messages,
    required String topic,
    required String level,
    required String levelLabel,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    return const EndResultAnalysis(
      overall: 'good',
      bestMomentQuote: 'I think technology makes our lives much better',
      bestMomentNote: 'Great use of comparative structure — very natural!',
      courageOrMotivationType: 'moment_of_courage',
      courageOrMotivationContent:
          "You kept going even when you weren't sure of the word — that takes real courage!",
      tryNextTimeSkill: "connecting ideas with 'because'",
      tryNextTimeExample:
          "I like this app because it helps me learn English.",
      transcriptNotes: [
        EndResultTranscriptNote(
          speaker: 'student',
          text: 'technology makes our lives much better',
          note: 'Great comparative phrasing!',
        ),
        EndResultTranscriptNote(
          speaker: 'zoe',
          text: "That's a great thought!",
        ),
      ],
    );
  }
}
