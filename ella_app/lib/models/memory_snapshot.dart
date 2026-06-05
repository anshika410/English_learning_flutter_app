// In-memory snapshot pushed after each endChat.
// Mirrors the simulator's `snapshots` array — used by the Memory tab to show
// how the learner's state evolved chat by chat.

class MemorySnapshot {
  final int chat;
  final String model; // 'micro-skill' | 'units'
  final List<String> owned;
  final List<String> emerging;
  final List<String> dueFlat; // primary + watching

  const MemorySnapshot({
    required this.chat,
    required this.model,
    required this.owned,
    required this.emerging,
    required this.dueFlat,
  });
}
