// UI-layer chat message. Flutter-safe (no core/ dependency).
// Kept separate from ConvMessage (core/) to avoid Flutter imports in engine code.

enum MessageSender { zoe, child, system }

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    String? id,
    required this.sender,
    required String text,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now(),
        text = sender == MessageSender.zoe
            ? text
                .replaceAll('"', '')
                .replaceAll('“', '')
                .replaceAll('”', '')
                .replaceAll('**', '')
                .replaceAll('*', '')
            : text;

  // transcript table row — matches ELLA-Final-Build-Spec.md Part C.
  Map<String, dynamic> toTranscriptRow({
    required String sessionId,
    required String childId,
    required int turnIndex,
  }) => {
    'session_id': sessionId,
    'child_id': childId,
    'turn_index': turnIndex,
    'speaker': sender == MessageSender.zoe ? 'zoe' : 'child',
    'text': text,
    'recorded_at': timestamp.toIso8601String(),
  };
}
