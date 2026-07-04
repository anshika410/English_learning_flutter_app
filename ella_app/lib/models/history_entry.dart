// Compact per-chat summary for the History tab.
// Mirrors the simulator's `history` array: chat number, level, model, owned/
// emerging counts, changes that happened, turns, aimed targets, and how many hit.

class HistoryEntry {
  final int chat;
  final String level;
  final String model; // 'micro-skill' | 'units'
  final int owned;
  final int emerging;
  final int changes;
  final int turns;
  final int aimed;
  final int hit;

  const HistoryEntry({
    required this.chat,
    required this.level,
    required this.model,
    required this.owned,
    required this.emerging,
    required this.changes,
    required this.turns,
    required this.aimed,
    required this.hit,
  });
}
