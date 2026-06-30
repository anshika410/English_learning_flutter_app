// Garden data model — mirrors GET /users/me/garden.
// See docs/garden-progress-system. The API is the source of truth for the
// garden view; the engine no longer computes these states client-side.

import 'package:flutter/widgets.dart';

import '../core/theme_colors.dart';

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

  /// The full-bloom plant art for this strand (FLU=Rose, VOC=Marigold, GRA=Purple).
  String get bloomAsset => switch (this) {
        Strand.voc => 'assets/gardent-view/plannts-vocobulary-bloom.svg',
        Strand.flu => 'assets/gardent-view/plants-fluency-bloom.svg',
        Strand.gra => 'assets/gardent-view/plants-grammer-bloom.svg',
        Strand.unknown => 'assets/gardent-view/plannts-vocobulary-bloom.svg',
      };

  /// Small icon used in the skill detail dialogs.
  String get icon => switch (this) {
        Strand.voc => 'assets/information-box/people-who-support-svgrepo-com 1.svg',
        Strand.gra => 'assets/information-box/clock.svg',
        Strand.flu => 'assets/information-box/talk-svgrepo-com.svg',
        Strand.unknown => 'assets/information-box/flower.svg',
      };

  Color get tagColor => switch (this) {
        Strand.voc => EllaColors.limeDark,
        Strand.gra => EllaColors.grapeMain,
        Strand.flu => EllaColors.roseMain,
        Strand.unknown => EllaColors.muted,
      };

  Color get tagBg => switch (this) {
        Strand.voc => EllaColors.limeLightest,
        Strand.gra => EllaColors.grapeLightest,
        Strand.flu => EllaColors.roseLightest,
        Strand.unknown => EllaColors.surface,
      };
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

  const GardenEvidence({
    required this.quote,
    required this.confidence,
    required this.prompted,
  });

  factory GardenEvidence.fromJson(Map<String, dynamic> j) => GardenEvidence(
        quote: (j['evidence'] ?? j['quote'] ?? '').toString(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        prompted: j['prompted'] as bool? ?? false,
      );
}

class GardenSkill {
  final String id;
  final Strand strand;
  final String text;
  final SkillStatus status;
  final int sightings;
  final List<GardenEvidence> evidence;

  const GardenSkill({
    required this.id,
    required this.strand,
    required this.text,
    required this.status,
    required this.sightings,
    required this.evidence,
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
      );
}

class GardenStep {
  final int step;
  final String name;
  final String focus;
  final bool isCompleted;
  final List<GardenSkill> skills;

  const GardenStep({
    required this.step,
    required this.name,
    required this.focus,
    required this.isCompleted,
    required this.skills,
  });

  /// A plot is "active" (grassy) once any skill is past locked.
  bool get hasGrowth => skills.any((s) => s.status != SkillStatus.locked);

  factory GardenStep.fromJson(Map<String, dynamic> j) => GardenStep(
        step: (j['step'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        focus: (j['focus'] ?? '').toString(),
        isCompleted: j['isCompleted'] as bool? ?? j['is_completed'] as bool? ?? false,
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
            (j['activeStepIndex'] as num?)?.toInt() ?? (j['active_step_index'] as num?)?.toInt() ?? 0,
        recommendedTopic:
            (j['recommendedTopic'] ?? j['recommended_topic'] ?? '').toString(),
        steps: [
          for (final s in (j['steps'] as List? ?? const []))
            GardenStep.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );
}
