// Garden data model — mirrors GET /users/me/garden.
// See docs/garden-progress-system. The API is the source of truth for the
// garden view; the engine no longer computes these states client-side.

import 'package:flutter/widgets.dart';

import '../core/theme_colors.dart';

String _optionalString(Map<String, dynamic> j, List<String> keys) {
  for (final key in keys) {
    final value = j[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

/// Learning strand a skill belongs to.
enum Strand { voc, gra, flu, unknown }

Strand strandFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'VOC':
      return Strand.voc;
    case 'GRA':
      return Strand.gra;
    case 'FLU':
      return Strand.flu;
    default:
      return Strand.unknown;
  }
}

extension StrandInfo on Strand {
  String get label => switch (this) {
    Strand.voc => 'Vocabulary',
    Strand.gra => 'Grammar',
    Strand.flu => 'Fluency',
    Strand.unknown => 'Skill',
  };

  /// File-name stem for this strand's plant art in assets/garden/plants/.
  String get _plantStem => switch (this) {
    Strand.voc => 'vocab',
    Strand.flu => 'fluency',
    Strand.gra => 'grammar',
    Strand.unknown => 'vocab',
  };

  /// Growth-stage plant art for this strand, from assets/garden/plants/.
  /// Stages are keyed off sightings (1 → seedling, 2 → young, ≥3 → bloom).
  String get seedlingAsset => 'assets/garden/plants/$_plantStem-seedling.svg';
  String get youngAsset => 'assets/garden/plants/$_plantStem-young.svg';

  /// The full-bloom plant art for this strand (FLU=Rose, VOC=Marigold, GRA=Purple).
  String get bloomAsset => 'assets/garden/plants/$_plantStem-bloom.svg';

  /// Small icon used in the skill detail dialogs.
  String get icon => switch (this) {
    Strand.voc => 'assets/information-box/people-who-support-svgrepo-com 1.svg',
    Strand.gra => 'assets/information-box/clock.svg',
    Strand.flu => 'assets/information-box/talk-svgrepo-com.svg',
    Strand.unknown => 'assets/information-box/flower.svg',
  };

  /// Botanical Berry track identity for this strand.
  TrackColors get track => switch (this) {
    Strand.voc => TrackColors.vocabulary,
    Strand.flu => TrackColors.fluency,
    Strand.gra => TrackColors.grammar,
    Strand.unknown => const TrackColors(
      surface: EllaColors.surfaceVariant,
      border: EllaColors.border,
      main: EllaColors.textTertiary,
      text: EllaColors.textTertiary,
    ),
  };

  Color get tagColor => track.text;

  Color get tagBg => track.surface;
}

/// Skill mastery state.
enum SkillStatus { owned, emerging, locked }

SkillStatus statusFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'owned':
      return SkillStatus.owned;
    case 'emerging':
      return SkillStatus.emerging;
    default:
      return SkillStatus.locked;
  }
}

extension SkillStatusInfo on SkillStatus {
  String get tag => switch (this) {
    SkillStatus.owned => 'Bloomed',
    SkillStatus.emerging => 'Growing',
    SkillStatus.locked => 'Not planted',
  };
}

/// Visual growth stage shown on a plot.
enum PlantStage { bare, sprout, growing, bloom }

/// Maps (status, sightings) → growth stage. Owned always blooms (no separate
/// bud asset); emerging grows from sprout → growing as sightings accrue.
PlantStage plantStageFor(SkillStatus status, int sightings) {
  switch (status) {
    case SkillStatus.owned:
      return PlantStage.bloom;
    case SkillStatus.emerging:
      return sightings >= 1 ? PlantStage.growing : PlantStage.sprout;
    case SkillStatus.locked:
      return PlantStage.bare;
  }
}

class GardenEvidence {
  final String quote;
  final double confidence;
  final bool prompted;

  /// The conversation topic this evidence was collected under (from the API,
  /// shown as the caption under the quote in the Skill Sheet).
  final String topic;

  /// When this evidence was recorded (from the API), shown as a relative
  /// timestamp ("2 days ago") after the topic. Null if the API omits it.
  final DateTime? createdAt;

  const GardenEvidence({
    required this.quote,
    required this.confidence,
    required this.prompted,
    this.topic = '',
    this.createdAt,
  });

  factory GardenEvidence.fromJson(Map<String, dynamic> j) => GardenEvidence(
    quote: (j['evidence'] ?? j['quote'] ?? '').toString(),
    confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
    prompted: j['prompted'] as bool? ?? false,
    topic: (j['topic'] ?? j['conversation_topic'] ?? '').toString(),
    createdAt: DateTime.tryParse(
      (j['created_at'] ?? j['recorded_at'] ?? j['timestamp'] ?? '').toString(),
    ),
  );
}

class GardenSkill {
  final String id;
  final Strand strand;
  final String text;
  final SkillStatus status;
  final int sightings;
  final List<GardenEvidence> evidence;
  final String icon;

  const GardenSkill({
    required this.id,
    required this.strand,
    required this.text,
    required this.status,
    required this.sightings,
    required this.evidence,
    this.icon = '',
  });

  PlantStage get stage => plantStageFor(status, sightings);

  factory GardenSkill.fromJson(Map<String, dynamic> j) => GardenSkill(
    id: (j['id'] ?? '').toString(),
    strand: strandFromString(j['strand'] as String?),
    text: (j['text'] ?? '').toString(),
    status: statusFromString(j['status'] as String?),
    sightings: (j['sightings'] as num?)?.toInt() ?? 0,
    evidence: [
      for (final e in (j['evidence'] as List? ?? const []))
        GardenEvidence.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
    icon: _optionalString(j, const [
      'icon',
      'icon_id',
      'icon_asset',
      'icon_path',
    ]),
  );
}

class GardenStep {
  final int step;
  final String name;
  final String focus;
  final String description;
  final String icon;
  final bool isCompleted;
  final List<GardenSkill> skills;

  const GardenStep({
    required this.step,
    required this.name,
    required this.focus,
    required this.isCompleted,
    required this.skills,
    this.description = '',
    this.icon = '',
  });

  /// A plot is "active" (grassy) once any skill is past locked.
  bool get hasGrowth => skills.any((s) => s.status != SkillStatus.locked);

  factory GardenStep.fromJson(Map<String, dynamic> j) => GardenStep(
    // API returns `unit`; older payloads used `step`. Accept both.
    step: (j['step'] as num?)?.toInt() ?? (j['unit'] as num?)?.toInt() ?? 0,
    name: (j['name'] ?? '').toString(),
    focus: (j['focus'] ?? '').toString(),
    description: _optionalString(j, const [
      'description',
      'unit_description',
      'focus',
    ]),
    icon: _optionalString(j, const [
      'icon',
      'icon_id',
      'icon_asset',
      'icon_path',
    ]),
    isCompleted:
        j['isCompleted'] as bool? ?? j['is_completed'] as bool? ?? false,
    skills: [
      for (final s in (j['skills'] as List? ?? const []))
        GardenSkill.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
  );
}

class GardenData {
  final String level;
  final String levelLabel;
  final String theme;
  final int activeStepIndex;
  final String recommendedTopic;
  final List<GardenStep> steps;

  const GardenData({
    required this.level,
    required this.levelLabel,
    required this.theme,
    required this.activeStepIndex,
    required this.recommendedTopic,
    required this.steps,
  });

  factory GardenData.fromJson(Map<String, dynamic> j) => GardenData(
    level: (j['level'] ?? '').toString(),
    levelLabel: (j['levelLabel'] ?? j['level_label'] ?? '').toString(),
    theme: (j['theme'] ?? '').toString(),
    activeStepIndex:
        (j['activeStepIndex'] as num?)?.toInt() ??
        (j['active_step_index'] as num?)?.toInt() ??
        0,
    recommendedTopic: (j['recommendedTopic'] ?? j['recommended_topic'] ?? '')
        .toString(),
    // API returns `units`; older payloads used `steps`. Accept both.
    steps: [
      for (final s in (j['steps'] as List? ?? j['units'] as List? ?? const []))
        GardenStep.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
  );
}
