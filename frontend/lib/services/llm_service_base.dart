import '../models/chat_message.dart';
import '../models/end_result_analysis.dart';
import '../models/focus_options.dart';
import 'llm_service.dart';

/// Abstract interface for LLM operations.
/// Both [LlmService] (real API) and [MockLlmService] (scripted) implement this.
/// To switch between them, change [kUseMockLlm] in lib/mock/mock_config.dart.
abstract class LlmServiceBase {
  Future<({String starter, String headerTitle})> generateConversationStarter({
    String? topic,
  });

  Future<ConversationTurnResult> sendMessage(
    List<ChatMessage> history, {
    String? topic,
    String? level,
    String? levelLabel,
    int currentTurn = 1,
    FocusSettings? focusSettings,
  });

  Future<EndResultAnalysis?> analyzeConversation({
    required List<ChatMessage> messages,
    required String topic,
    required String level,
    required String levelLabel,
  });

  Future<PlacementMessageResult> sendPlacementMessage(
    List<Map<String, String>> messages, {
    String promptPath =
        'assets/prompts/placement-check-adaptive-friendly.md',
    String userName = 'there',
    String userAge = '15',
  });
}
