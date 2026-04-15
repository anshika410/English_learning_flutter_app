import 'latency_info.dart';

enum MessageRole { user, assistant, system }

class ChatMessage {
  final MessageRole role;
  final String content;
  final String? correction; // grammar/pronunciation feedback
  final LatencyInfo? latency; // per-turn latency breakdown
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.correction,
    this.latency,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toApiMap() => {
        'role': role.name,
        'content': content,
      };
}
