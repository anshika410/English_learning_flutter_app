// Pure-Dart data classes used by the engine.
// No Flutter imports. No network imports.

class SkillScore {
  final String id;
  final double confidence; // 0..1
  final bool prompted; // false = spontaneous (counts toward strength)
  final String evidence; // short learner quote, or ''

  const SkillScore({
    required this.id,
    required this.confidence,
    required this.prompted,
    this.evidence = '',
  });

  factory SkillScore.fromJson(Map<String, dynamic> j) => SkillScore(
    id: j['id'] as String,
    confidence: (j['confidence'] as num).toDouble(),
    prompted: j['prompted'] as bool,
    evidence: (j['evidence'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'confidence': confidence,
    'prompted': prompted,
    'evidence': evidence,
  };
}

class StateChange {
  final String id;
  final String from; // 'locked' | 'emerging' | 'owned'
  final String to;

  const StateChange({required this.id, required this.from, required this.to});

  @override
  String toString() => '$id: $from → $to';
}

class DueNext {
  final String? primary;
  final List<String> watching;

  const DueNext({this.primary, this.watching = const []});

  static const DueNext empty = DueNext();

  List<String> get flat => [?primary, ...watching];

  DueNext copyWith({
    String? primary,
    bool clearPrimary = false,
    List<String>? watching,
  }) => DueNext(
    primary: clearPrimary ? null : (primary ?? this.primary),
    watching: watching ?? this.watching,
  );

  factory DueNext.fromJson(Map<String, dynamic> j) => DueNext(
    primary: j['primary'] as String?,
    watching: List<String>.from((j['watching'] as List?) ?? []),
  );

  Map<String, dynamic> toJson() => {'primary': primary, 'watching': watching};
}

class MemoryState {
  final String childId;
  final String level; // 'A1'..'C2'
  final String progressionModel; // 'micro-skill' | 'units'
  final List<String> owned;
  final List<String> emerging;
  final DueNext dueNext;
  final List<String> lastTopics; // ring buffer, max 5
  final String lastTimeRecap; // server-authored recap line for the home screen
  final String interests; // free-text, feeds topic picker
  final Map<String, int> sightings; // per-skill qualifying count
  final Map<String, int> strength; // per-skill unprompted count
  final Map<String, String> lastSeen; // skill_id → 'yyyy-MM-dd'
  final int effortTimesSpoken; // lifetime total, only ever rises
  final int chatCount;
  final int updatedAfterChat;

  const MemoryState({
    required this.childId,
    required this.level,
    this.progressionModel = 'units',
    this.owned = const [],
    this.emerging = const [],
    this.dueNext = const DueNext(),
    this.lastTopics = const [],
    this.lastTimeRecap = '',
    this.interests = '',
    this.sightings = const {},
    this.strength = const {},
    this.lastSeen = const {},
    this.effortTimesSpoken = 0,
    this.chatCount = 0,
    this.updatedAfterChat = 0,
  });

  MemoryState copyWith({
    String? childId,
    String? level,
    String? progressionModel,
    List<String>? owned,
    List<String>? emerging,
    DueNext? dueNext,
    List<String>? lastTopics,
    String? lastTimeRecap,
    String? interests,
    Map<String, int>? sightings,
    Map<String, int>? strength,
    Map<String, String>? lastSeen,
    int? effortTimesSpoken,
    int? chatCount,
    int? updatedAfterChat,
  }) => MemoryState(
    childId: childId ?? this.childId,
    level: level ?? this.level,
    progressionModel: progressionModel ?? this.progressionModel,
    owned: owned ?? this.owned,
    emerging: emerging ?? this.emerging,
    dueNext: dueNext ?? this.dueNext,
    lastTopics: lastTopics ?? this.lastTopics,
    lastTimeRecap: lastTimeRecap ?? this.lastTimeRecap,
    interests: interests ?? this.interests,
    sightings: sightings ?? this.sightings,
    strength: strength ?? this.strength,
    lastSeen: lastSeen ?? this.lastSeen,
    effortTimesSpoken: effortTimesSpoken ?? this.effortTimesSpoken,
    chatCount: chatCount ?? this.chatCount,
    updatedAfterChat: updatedAfterChat ?? this.updatedAfterChat,
  );

  factory MemoryState.fresh(String level, {String childId = 'demo'}) =>
      MemoryState(childId: childId, level: level);

  // Supabase stores memory_state as a JSONB column called `state`.
  // Column names match ELLA-Final-Build-Spec.md Part C exactly.
  factory MemoryState.fromJson(String childId, Map<String, dynamic> j) {
    final due = j['due_next'] != null
        ? DueNext.fromJson(Map<String, dynamic>.from(j['due_next'] as Map))
        : const DueNext();
    return MemoryState(
      childId: childId,
      level: j['level'] as String? ?? 'A1',
      progressionModel: j['progression_model'] as String? ?? 'units',
      owned: List<String>.from((j['owned'] as List?) ?? []),
      emerging: List<String>.from((j['emerging'] as List?) ?? []),
      dueNext: due,
      lastTopics: List<String>.from((j['last_topics'] as List?) ?? []),
      lastTimeRecap: j['last_time_recap'] as String? ?? '',
      interests: j['interests'] as String? ?? '',
      sightings: Map<String, int>.from(
        (j['sightings'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ) ??
            {},
      ),
      strength: Map<String, int>.from(
        (j['strength'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ) ??
            {},
      ),
      lastSeen: Map<String, String>.from(
        (j['last_seen'] as Map?)?.map(
              (k, v) => MapEntry(k as String, v as String),
            ) ??
            {},
      ),
      effortTimesSpoken: (j['effort_times_spoken'] as num?)?.toInt() ?? 0,
      chatCount: (j['chat_count'] as num?)?.toInt() ?? 0,
      updatedAfterChat: (j['updated_after_chat'] as num?)?.toInt() ?? 0,
    );
  }

  // Keys map 1:1 to memory_state columns.
  // `interests` lives on the `children` table — NOT here.
  Map<String, dynamic> toJson() => {
    'level': level,
    'progression_model': progressionModel,
    'owned': owned,
    'emerging': emerging,
    'due_next': dueNext.toJson(),
    'last_topics': lastTopics,
    'sightings': sightings,
    'strength': strength,
    'last_seen': lastSeen,
    'effort_times_spoken': effortTimesSpoken,
    'chat_count': chatCount,
    'updated_after_chat': updatedAfterChat,
  };
}

// Lightweight message used by buildConvPrompt — no Flutter dependency.
class ConvMessage {
  final String role; // 'zoe' | 'user' | 'sys'
  final String text;

  const ConvMessage({required this.role, required this.text});
}
