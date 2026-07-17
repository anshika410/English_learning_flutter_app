// Pure-Dart data classes used by the engine.
// No Flutter imports. No network imports.

import 'placement.dart';

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

/// A single home-screen topic suggestion. `name` is the full topic sent to the
/// backend (`POST /session`); `label` is the short chip/CTA text shown to the
/// child. `icon` is a slug (asset name, may be unmapped) and `starter` is Zoe's
/// opening line for the topic (informational — the server issues its own).
class TopicChoice {
  final String name;
  final String label;
  final String icon;
  final String starter;

  const TopicChoice({
    required this.name,
    this.label = '',
    this.icon = '',
    this.starter = '',
  });

  /// The text to show on chips / the CTA — the short label, or the full name
  /// when no label was provided.
  String get display => label.isNotEmpty ? label : name;

  factory TopicChoice.fromJson(Map<String, dynamic> j) => TopicChoice(
    name: j['name'] as String? ?? '',
    label: j['label'] as String? ?? '',
    icon: j['icon'] as String? ?? '',
    starter: j['starter'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'label': label,
    'icon': icon,
    'starter': starter,
  };
}

class NextTopics {
  final TopicChoice? recommended;
  final List<TopicChoice> alternatives;

  const NextTopics({this.recommended, this.alternatives = const []});

  static const NextTopics empty = NextTopics();

  factory NextTopics.fromJson(Map<String, dynamic> j) => NextTopics(
    recommended: j['recommended'] is Map
        ? TopicChoice.fromJson(
            Map<String, dynamic>.from(j['recommended'] as Map),
          )
        : null,
    alternatives: [
      for (final item in (j['alternatives'] as List?) ?? const [])
        TopicChoice.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
  );

  Map<String, dynamic> toJson() => {
    'recommended': recommended?.toJson(),
    'alternatives': [for (final a in alternatives) a.toJson()],
  };
}

class MemoryState {
  final String childId;
  final String level; // 'A1'..'C2'
  // Whether the server actually returned a level. `level` falls back to 'A1'
  // when absent so the engine always has one; this flag distinguishes a real
  // placement level from that fallback (drives the bloom vs sprout garden).
  final bool hasLevel;
  final String progressionModel; // 'micro-skill' | 'units'
  final List<String> owned;
  final List<String> emerging;
  final DueNext dueNext;
  final List<String> lastTopics; // ring buffer, max 5
  final String lastTimeRecap; // server-authored recap line for the home screen
  final NextTopics nextTopics; // recommended + alternative topics for home
  final String interests; // free-text, feeds topic picker
  final Map<String, int> sightings; // per-skill qualifying count
  final Map<String, int> strength; // per-skill unprompted count
  final Map<String, String> lastSeen; // skill_id → 'yyyy-MM-dd'
  final int effortTimesSpoken; // lifetime total, only ever rises
  final int chatCount;
  final int updatedAfterChat;
  final String? name;
  final int? age;
  // Server-owned placement result (null until the student has been levelled).
  // Its presence gates the first-run placement flow. Read-only — not in toJson.
  final PlacementInfo? placement;

  const MemoryState({
    required this.childId,
    required this.level,
    this.hasLevel = true,
    this.progressionModel = 'units',
    this.owned = const [],
    this.emerging = const [],
    this.dueNext = const DueNext(),
    this.lastTopics = const [],
    this.lastTimeRecap = '',
    this.nextTopics = NextTopics.empty,
    this.interests = '',
    this.sightings = const {},
    this.strength = const {},
    this.lastSeen = const {},
    this.effortTimesSpoken = 0,
    this.chatCount = 0,
    this.updatedAfterChat = 0,
    this.name,
    this.age,
    this.placement,
  });

  MemoryState copyWith({
    String? childId,
    String? level,
    bool? hasLevel,
    String? progressionModel,
    List<String>? owned,
    List<String>? emerging,
    DueNext? dueNext,
    List<String>? lastTopics,
    String? lastTimeRecap,
    NextTopics? nextTopics,
    String? interests,
    Map<String, int>? sightings,
    Map<String, int>? strength,
    Map<String, String>? lastSeen,
    int? effortTimesSpoken,
    int? chatCount,
    int? updatedAfterChat,
    String? name,
    int? age,
    PlacementInfo? placement,
  }) => MemoryState(
    childId: childId ?? this.childId,
    level: level ?? this.level,
    hasLevel: hasLevel ?? this.hasLevel,
    progressionModel: progressionModel ?? this.progressionModel,
    owned: owned ?? this.owned,
    emerging: emerging ?? this.emerging,
    dueNext: dueNext ?? this.dueNext,
    lastTopics: lastTopics ?? this.lastTopics,
    lastTimeRecap: lastTimeRecap ?? this.lastTimeRecap,
    nextTopics: nextTopics ?? this.nextTopics,
    interests: interests ?? this.interests,
    sightings: sightings ?? this.sightings,
    strength: strength ?? this.strength,
    lastSeen: lastSeen ?? this.lastSeen,
    effortTimesSpoken: effortTimesSpoken ?? this.effortTimesSpoken,
    chatCount: chatCount ?? this.chatCount,
    updatedAfterChat: updatedAfterChat ?? this.updatedAfterChat,
    name: name ?? this.name,
    age: age ?? this.age,
    placement: placement ?? this.placement,
  );

  factory MemoryState.fresh(String level, {String childId = 'demo'}) =>
      MemoryState(childId: childId, level: level);

  // Supabase stores memory_state as a JSONB column called `state`.
  // Column names match ELLA-Final-Build-Spec.md Part C exactly.
  factory MemoryState.fromJson(String childId, Map<String, dynamic> j) {
    final due = j['due_next'] != null
        ? DueNext.fromJson(Map<String, dynamic>.from(j['due_next'] as Map))
        : const DueNext();
    final profile = j['profile'] is Map ? Map<String, dynamic>.from(j['profile'] as Map) : null;
    final name = profile?['name'] as String?;
    final age = (profile?['age'] as num?)?.toInt();
    return MemoryState(
      childId: childId,
      level: j['level'] as String? ?? 'A1',
      hasLevel: (j['level'] as String?)?.isNotEmpty ?? false,
      progressionModel: j['progression_model'] as String? ?? 'units',
      owned: List<String>.from((j['owned'] as List?) ?? []),
      emerging: List<String>.from((j['emerging'] as List?) ?? []),
      dueNext: due,
      lastTopics: List<String>.from((j['last_topics'] as List?) ?? []),
      lastTimeRecap: j['last_time_recap'] as String? ?? '',
      nextTopics: j['next_topics'] is Map
          ? NextTopics.fromJson(
              Map<String, dynamic>.from(j['next_topics'] as Map),
            )
          : NextTopics.empty,
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
      name: name,
      age: age,
      placement: j['placement'] is Map
          ? PlacementInfo.fromJson(
              Map<String, dynamic>.from(j['placement'] as Map),
            )
          : null,
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
    'next_topics': nextTopics.toJson(),
    'sightings': sightings,
    'strength': strength,
    'last_seen': lastSeen,
    'effort_times_spoken': effortTimesSpoken,
    'chat_count': chatCount,
    'updated_after_chat': updatedAfterChat,
  };
}

// Lightweight conversation message — no Flutter dependency.
class ConvMessage {
  final String role; // 'zoe' | 'user' | 'sys'
  final String text;

  const ConvMessage({required this.role, required this.text});
}
