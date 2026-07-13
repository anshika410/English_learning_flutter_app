// Garden data provider — fetches GET /users/me/garden via the Ella API.
// Auth token is managed by EllaApiService via SharedPreferences. Refreshable so the
// Garden tab can pull fresh state after a session ends.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/curriculum_display_copy.dart';
import '../core/curriculum_icons.dart';
import '../models/child_memory.dart';
import '../models/garden.dart';
import 'service_providers.dart';

const List<GardenPreviewLevel> gardenPreviewLevels = [
  GardenPreviewLevel('A0', 'Dawn Glade'),
  GardenPreviewLevel('A1', 'Morning Meadow'),
  GardenPreviewLevel('A2', 'Midday Grove'),
  GardenPreviewLevel('B1', 'Golden Orchard'),
  GardenPreviewLevel('B2', 'Twilight Valley'),
  GardenPreviewLevel('C1', 'Starlight Summit'),
];

/// Canonical ordered garden sequence (A0 → C1). Shared by the preview
/// controller and the garden switcher sheet.
const List<GardenPreviewLevel> gardenSequence = gardenPreviewLevels;

/// One row in the garden switcher sheet.
class GardenSwitcherEntry {
  /// Level code, e.g. 'A0'…'C1'.
  final String code;

  /// Display name, e.g. 'Dawn Glade'.
  final String label;

  /// True for the garden the student is currently in ("You're here").
  final bool isCurrent;

  /// True for the single fogged "next garden" card (non-navigable).
  final bool isLocked;

  const GardenSwitcherEntry({
    required this.code,
    required this.label,
    required this.isCurrent,
    required this.isLocked,
  });
}

/// Builds the ordered list of switcher rows for [currentLevel].
///
/// Everything up to and including the current level is shown as unlocked;
/// the single next level in [gardenSequence] is appended as a locked/fog
/// card. Levels beyond the next one are omitted. When the current level is
/// the last in the sequence, no locked entry is appended.
///
/// An unknown/absent level falls back to the first entry in the sequence
/// (mirrors [_previewLabelFor]).
List<GardenSwitcherEntry> gardenSwitcherEntries(String currentLevel) {
  var currentIndex = gardenSequence.indexWhere((l) => l.code == currentLevel);
  if (currentIndex < 0) currentIndex = 0;

  final entries = <GardenSwitcherEntry>[];
  for (var i = 0; i <= currentIndex; i++) {
    final level = gardenSequence[i];
    entries.add(
      GardenSwitcherEntry(
        code: level.code,
        label: level.label,
        isCurrent: i == currentIndex,
        isLocked: false,
      ),
    );
  }
  final nextIndex = currentIndex + 1;
  if (nextIndex < gardenSequence.length) {
    final next = gardenSequence[nextIndex];
    entries.add(
      GardenSwitcherEntry(
        code: next.code,
        label: next.label,
        isCurrent: false,
        isLocked: true,
      ),
    );
  }
  return entries;
}

/// Optional in-app override of the garden level being *viewed* (not the
/// student's actual current level). Set when the user taps an unlocked
/// garden in the switcher; null means "show the level the API returned".
final selectedGardenLevelProvider = StateProvider<String?>((ref) => null);

int gardenLevelIndex(String level) {
  final code = _canonicalGardenLevel(level);
  return gardenSequence.indexWhere((entry) => entry.code == code);
}

bool isViewingCompletedPreviousGarden({
  required String currentLevel,
  required String viewedLevel,
}) {
  final currentIndex = gardenLevelIndex(currentLevel);
  final viewedIndex = gardenLevelIndex(viewedLevel);
  return currentIndex >= 0 && viewedIndex >= 0 && viewedIndex < currentIndex;
}

GardenData displayGardenDataFor({
  required GardenData currentGarden,
  required String viewedLevel,
}) {
  if (!isViewingCompletedPreviousGarden(
    currentLevel: currentGarden.level,
    viewedLevel: viewedLevel,
  )) {
    return currentGarden;
  }
  return completedPreviousGardenData(
    currentGarden: currentGarden,
    viewedLevel: viewedLevel,
  );
}

GardenData completedPreviousGardenData({
  required GardenData currentGarden,
  required String viewedLevel,
}) {
  final level = _canonicalGardenLevel(viewedLevel);
  final label = _previewLabelFor(level);
  if (CurriculumIcons.transitionForLevel(level) == null) {
    return GardenData(
      level: level,
      levelLabel: label,
      theme: label,
      activeStepIndex: currentGarden.activeStepIndex,
      recommendedTopic: currentGarden.recommendedTopic,
      steps: [
        for (final step in currentGarden.steps) _completedStepFromGarden(step),
      ],
    );
  }

  final steps = <GardenStep>[];
  for (var unitNumber = 1; unitNumber <= 5; unitNumber++) {
    final skillIds = CurriculumIcons.skillIdsForUnit(level, unitNumber);
    final displayName = CurriculumDisplayCopy.unitName(
      level: level,
      unit: unitNumber,
      fallback: '',
    );
    final displayDescription = CurriculumDisplayCopy.unitDescription(
      level: level,
      unit: unitNumber,
      fallback: '',
    );
    steps.add(
      GardenStep(
        step: unitNumber,
        name: displayName,
        focus: displayDescription,
        description: displayDescription,
        displayName: displayName,
        displayDescription: displayDescription,
        icon: CurriculumIcons.unitAsset(level, unitNumber) ?? '',
        isCompleted: true,
        skills: [
          for (final skillId in skillIds)
            _completedSkill(
              id: skillId,
              strand: _strandFromCurriculumSkillId(skillId),
              text: CurriculumDisplayCopy.skillText(
                level: level,
                unit: unitNumber,
                skillId: skillId,
                fallback: skillId,
              ),
              displayText: CurriculumDisplayCopy.skillText(
                level: level,
                unit: unitNumber,
                skillId: skillId,
                fallback: skillId,
              ),
              icon:
                  CurriculumIcons.skillAsset(level, unitNumber, skillId) ?? '',
            ),
        ],
      ),
    );
  }

  return GardenData(
    level: level,
    levelLabel: label,
    theme: label,
    activeStepIndex: steps.length,
    recommendedTopic: 'Placement',
    steps: steps,
  );
}

const String completedGardenIntroSeenPrefsKeyPrefix =
    'ella_completed_previous_garden_intro_seen_v1';
const String _completedGardenIntroUserIdPrefsKey = 'ella_api_user_id';

class CompletedGardenIntroSeenState {
  final bool loaded;
  final Set<String> seenLevels;

  const CompletedGardenIntroSeenState({
    required this.loaded,
    required this.seenLevels,
  });

  const CompletedGardenIntroSeenState.loading()
    : loaded = false,
      seenLevels = const {};

  bool contains(String level) =>
      seenLevels.contains(_canonicalGardenLevel(level));
}

class CompletedGardenIntroSeenController
    extends StateNotifier<CompletedGardenIntroSeenState> {
  String? _prefsKey;

  CompletedGardenIntroSeenController()
    : super(const CompletedGardenIntroSeenState.loading()) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_completedGardenIntroUserIdPrefsKey)?.trim();
    final scopedUserId = userId == null || userId.isEmpty
        ? 'anonymous'
        : userId;
    final key = '$completedGardenIntroSeenPrefsKeyPrefix:$scopedUserId';
    final seen = (prefs.getStringList(key) ?? const <String>[])
        .map(_canonicalGardenLevel)
        .toSet();
    _prefsKey = key;
    if (!mounted) return;
    state = CompletedGardenIntroSeenState(loaded: true, seenLevels: seen);
  }

  void markSeen(String level) {
    final code = _canonicalGardenLevel(level);
    final next = {...state.seenLevels, code};
    if (state.loaded && next.length == state.seenLevels.length) return;
    state = CompletedGardenIntroSeenState(
      loaded: state.loaded,
      seenLevels: next,
    );
    unawaited(_save(next));
  }

  Future<void> _save(Set<String> seenLevels) async {
    final key = _prefsKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final values = seenLevels.toList()..sort();
    await prefs.setStringList(key, values);
  }

  void clear() {
    if (state.seenLevels.isEmpty) return;
    state = CompletedGardenIntroSeenState(
      loaded: state.loaded,
      seenLevels: const {},
    );
    unawaited(_save(const {}));
  }
}

final completedGardenIntroSeenProvider =
    StateNotifierProvider<
      CompletedGardenIntroSeenController,
      CompletedGardenIntroSeenState
    >((ref) => CompletedGardenIntroSeenController());

Strand _strandFromCurriculumSkillId(String skillId) {
  final parts = skillId.split('-');
  return parts.length >= 2 ? strandFromString(parts[1]) : Strand.unknown;
}

String _canonicalGardenLevel(String level) {
  final upper = level.trim().toUpperCase();
  return gardenSequence.any((entry) => entry.code == upper)
      ? upper
      : gardenSequence.first.code;
}

GardenStep _completedStepFromGarden(GardenStep step) => GardenStep(
  step: step.step,
  name: step.name,
  focus: step.focus,
  description: step.description,
  displayName: step.displayName,
  displayDescription: step.displayDescription,
  icon: step.icon,
  isCompleted: true,
  skills: [
    for (final skill in step.skills)
      _completedSkill(
        id: skill.id,
        strand: skill.strand,
        text: skill.text,
        displayText: skill.displayText,
        icon: skill.icon,
      ),
  ],
);

GardenSkill _completedSkill({
  required String id,
  required Strand strand,
  required String text,
  String displayText = '',
  String icon = '',
}) => GardenSkill(
  id: id,
  strand: strand,
  text: text,
  displayText: displayText,
  status: SkillStatus.owned,
  sightings: 3,
  icon: icon,
  evidence: _completedGardenEvidence,
);

List<GardenEvidence> get _completedGardenEvidence => [
  GardenEvidence(
    quote: 'I can already use this when I talk.',
    confidence: 1,
    prompted: false,
    topic: 'Placement',
    createdAt: DateTime(2026, 7, 1),
  ),
  GardenEvidence(
    quote: 'Zoe found that this skill was already growing strongly.',
    confidence: 1,
    prompted: false,
    topic: 'Placement',
    createdAt: DateTime(2026, 7, 1),
  ),
  GardenEvidence(
    quote: 'This part of my garden was already grown.',
    confidence: 1,
    prompted: false,
    topic: 'Placement',
    createdAt: DateTime(2026, 7, 1),
  ),
];

enum GardenGrowthStage { seed, sprout, budding, bloomed }

extension GardenGrowthStageInfo on GardenGrowthStage {
  String get label => switch (this) {
    GardenGrowthStage.seed => 'Seed',
    GardenGrowthStage.sprout => 'Sprout',
    GardenGrowthStage.budding => 'Budding',
    GardenGrowthStage.bloomed => 'Bloomed',
  };

  String get key => switch (this) {
    GardenGrowthStage.seed => 'seed',
    GardenGrowthStage.sprout => 'sprout',
    GardenGrowthStage.budding => 'budding',
    GardenGrowthStage.bloomed => 'bloomed',
  };
}

GardenGrowthStage gardenGrowthStageFor({
  required SkillStatus status,
  required int sightings,
}) {
  if (status == SkillStatus.owned || sightings >= 3) {
    return GardenGrowthStage.bloomed;
  }
  if (sightings == 2) return GardenGrowthStage.budding;
  if (sightings == 1) return GardenGrowthStage.sprout;
  return GardenGrowthStage.seed;
}

class GardenGrowthRevealItem {
  final GardenStep step;
  final GardenSkill skill;
  final int stepIndex;
  final int skillIndex;
  final GardenGrowthStage fromStage;
  final GardenGrowthStage toStage;
  final GardenEvidence? evidence;

  /// When true, this reveal only waters the plant (no stage change / no plant
  /// pop). Used for the post-conversation "You watered your garden today"
  /// acknowledgement when a session aimed at a skill but nothing levelled up.
  final bool wateringOnly;

  /// When true, the session was a "quick hello" — no growth and fewer than a
  /// few turns. Suppresses all plant visuals (no spotlight, no watering can, no
  /// scroll-to-plant): shows only a plain black overlay + a simple sheet. The
  /// [step]/[skill] anchor is structural only and isn't rendered.
  final bool quickHello;

  const GardenGrowthRevealItem({
    required this.step,
    required this.skill,
    required this.stepIndex,
    required this.skillIndex,
    required this.fromStage,
    required this.toStage,
    this.evidence,
    this.wateringOnly = false,
    this.quickHello = false,
  });

  String get skillId => skill.id;

  String get revealKey =>
      '${skill.id}:${fromStage.key}:${toStage.key}:${evidence?.quote ?? ''}'
      '${wateringOnly ? ':water' : ''}${quickHello ? ':quick' : ''}';
}

class GardenGrowthRevealController
    extends StateNotifier<List<GardenGrowthRevealItem>> {
  GardenGrowthRevealController() : super(const []);

  void setQueue(List<GardenGrowthRevealItem> items) {
    state = List.unmodifiable(items);
  }

  void consumeCurrent() {
    if (state.isEmpty) return;
    state = List.unmodifiable(state.skip(1));
  }

  void clear() {
    if (state.isEmpty) return;
    state = const [];
  }
}

final gardenGrowthRevealProvider =
    StateNotifierProvider<
      GardenGrowthRevealController,
      List<GardenGrowthRevealItem>
    >((ref) => GardenGrowthRevealController());

enum PostConversationGardenRevealStatus { analyzing, resolved }

/// A retained, one-shot handoff from the conversation engine to the garden.
///
/// Unlike a widget-local flag, this survives the route transition from the
/// conversation screen to a newly mounted [GardenScreen]. The garden consumes
/// it only after fresh garden data is available and the reveal has been queued.
class PostConversationGardenReveal {
  final PostConversationGardenRevealStatus status;
  final int chatNumber;
  final int turnCount;
  final List<String> targetSkillIds;
  final Map<String, int> beforeSightings;
  final Map<String, int> afterSightings;
  final Set<String> beforeOwned;
  final Set<String> beforeEmerging;
  final Set<String> afterOwned;
  final Set<String> afterEmerging;
  final List<SkillScore> sessionScores;

  const PostConversationGardenReveal({
    required this.status,
    required this.chatNumber,
    required this.turnCount,
    required this.targetSkillIds,
    required this.beforeSightings,
    this.afterSightings = const {},
    required this.beforeOwned,
    required this.beforeEmerging,
    this.afterOwned = const {},
    this.afterEmerging = const {},
    this.sessionScores = const [],
  });

  bool get isResolved => status == PostConversationGardenRevealStatus.resolved;
}

class PostConversationGardenRevealController
    extends StateNotifier<PostConversationGardenReveal?> {
  PostConversationGardenRevealController() : super(null);

  void begin({
    required int chatNumber,
    required int turnCount,
    required List<String> targetSkillIds,
    required MemoryState before,
  }) {
    state = PostConversationGardenReveal(
      status: PostConversationGardenRevealStatus.analyzing,
      chatNumber: chatNumber,
      turnCount: turnCount,
      targetSkillIds: List.unmodifiable(targetSkillIds),
      beforeSightings: Map.unmodifiable(before.sightings),
      beforeOwned: Set.unmodifiable(before.owned),
      beforeEmerging: Set.unmodifiable(before.emerging),
    );
  }

  void resolve({
    required int chatNumber,
    required int turnCount,
    required List<String> targetSkillIds,
    required MemoryState before,
    required MemoryState after,
    required List<SkillScore> sessionScores,
  }) {
    state = PostConversationGardenReveal(
      status: PostConversationGardenRevealStatus.resolved,
      chatNumber: chatNumber,
      turnCount: turnCount,
      targetSkillIds: List.unmodifiable(targetSkillIds),
      beforeSightings: Map.unmodifiable(before.sightings),
      afterSightings: Map.unmodifiable(after.sightings),
      beforeOwned: Set.unmodifiable(before.owned),
      beforeEmerging: Set.unmodifiable(before.emerging),
      afterOwned: Set.unmodifiable(after.owned),
      afterEmerging: Set.unmodifiable(after.emerging),
      sessionScores: List.unmodifiable(sessionScores),
    );
  }

  void consume(int chatNumber) {
    if (state?.chatNumber == chatNumber) state = null;
  }

  void clear() => state = null;
}

final postConversationGardenRevealProvider =
    StateNotifierProvider<
      PostConversationGardenRevealController,
      PostConversationGardenReveal?
    >((ref) => PostConversationGardenRevealController());

/// Resolves real growth from the memory snapshots captured around end-chat.
/// Garden data supplies the canonical visual/copy object, while the snapshots
/// make the comparison independent of whether a previous Garden route existed.
List<GardenGrowthRevealItem> buildPostConversationGrowthRevealItems({
  required GardenData after,
  required PostConversationGardenReveal result,
}) {
  if (!result.isResolved) return const [];

  final scoreById = <String, SkillScore>{};
  for (final score in result.sessionScores) {
    if (score.evidence.trim().isEmpty) continue;
    final current = scoreById[score.id];
    if (current == null || score.confidence > current.confidence) {
      scoreById[score.id] = score;
    }
  }

  final items = <GardenGrowthRevealItem>[];
  for (var stepIndex = 0; stepIndex < after.steps.length; stepIndex++) {
    final step = after.steps[stepIndex];
    for (var skillIndex = 0; skillIndex < step.skills.length; skillIndex++) {
      final skill = step.skills[skillIndex];
      final beforeSightings = result.beforeSightings[skill.id] ?? 0;
      final afterSightings = result.afterSightings[skill.id] ?? skill.sightings;
      final fromStatus = _snapshotStatus(
        skill.id,
        result.beforeOwned,
        result.beforeEmerging,
      );
      final toStatus = _snapshotStatus(
        skill.id,
        result.afterOwned,
        result.afterEmerging,
      );
      final fromStage = gardenGrowthStageFor(
        status: fromStatus,
        sightings: beforeSightings,
      );
      final toStage = gardenGrowthStageFor(
        status: toStatus,
        sightings: afterSightings,
      );
      if (_growthStageRank(toStage) <= _growthStageRank(fromStage)) continue;

      items.add(
        GardenGrowthRevealItem(
          step: step,
          skill: skill,
          stepIndex: stepIndex,
          skillIndex: skillIndex,
          fromStage: fromStage,
          toStage: toStage,
          evidence: _evidenceFromScore(scoreById[skill.id]),
        ),
      );
    }
  }
  return List.unmodifiable(items);
}

int _growthStageRank(GardenGrowthStage stage) => switch (stage) {
  GardenGrowthStage.seed => 0,
  GardenGrowthStage.sprout => 1,
  GardenGrowthStage.budding => 2,
  GardenGrowthStage.bloomed => 3,
};

SkillStatus _snapshotStatus(
  String skillId,
  Set<String> owned,
  Set<String> emerging,
) {
  if (owned.contains(skillId)) return SkillStatus.owned;
  if (emerging.contains(skillId)) return SkillStatus.emerging;
  return SkillStatus.locked;
}

List<GardenGrowthRevealItem> buildGardenGrowthRevealItems({
  required GardenData? before,
  required GardenData after,
  bool inferFromAfter = false,
}) {
  if (before == null && !inferFromAfter) return const [];

  final beforeById = <String, GardenSkill>{};
  if (before != null) {
    for (final step in before.steps) {
      for (final skill in step.skills) {
        beforeById[skill.id] = skill;
      }
    }
  }

  final items = <GardenGrowthRevealItem>[];
  for (var stepIndex = 0; stepIndex < after.steps.length; stepIndex++) {
    final step = after.steps[stepIndex];
    for (var skillIndex = 0; skillIndex < step.skills.length; skillIndex++) {
      final skill = step.skills[skillIndex];
      final previous = beforeById[skill.id];
      final shouldInfer =
          before == null &&
          inferFromAfter &&
          skill.sightings > 0 &&
          (skill.id.startsWith('preview-growth') ||
              skill.id.startsWith('preview-two') ||
              items.isEmpty);
      final grewExactly =
          previous != null && skill.sightings > previous.sightings;
      if (!grewExactly && !shouldInfer) continue;

      final fromSightings = grewExactly
          ? previous.sightings
          : _inferredPreviousSightings(skill.sightings);
      final fromStatus = grewExactly
          ? previous.status
          : _statusForInferredSightings(fromSightings);
      final fromStage = gardenGrowthStageFor(
        status: fromStatus,
        sightings: fromSightings,
      );
      final toStage = gardenGrowthStageFor(
        status: skill.status,
        sightings: skill.sightings,
      );
      if (fromStage == toStage) continue;

      items.add(
        GardenGrowthRevealItem(
          step: step,
          skill: skill,
          stepIndex: stepIndex,
          skillIndex: skillIndex,
          fromStage: fromStage,
          toStage: toStage,
          evidence: _growthEvidenceFor(previous, skill),
        ),
      );
    }
  }
  return List.unmodifiable(items);
}

/// Builds the post-conversation "no growth" reveal. Two tiers, keyed on
/// [turnCount]:
///
/// - **Quick hello** (`turnCount < 3`): a lighter acknowledgement — no plant
///   spotlight/watering, just a plain overlay + simple sheet. Resolves an anchor
///   skill (aimed-at first, else the garden's first skill) purely for structure;
///   returns null only when the garden has no skills at all.
/// - **Watering** (`turnCount >= 3`): spotlights + waters the plot containing
///   the first *aimed-at* skill that exists in [after], carrying the child's
///   highest-confidence line from the whole session as a "line to remember".
///   Falls back to an active, non-owned garden skill when the backend target
///   cannot be resolved.
GardenGrowthRevealItem? buildGardenWateringRevealItem({
  required GardenData after,
  required List<String> aimedAt,
  required int turnCount,
  List<String> fallbackSkillIds = const [],
  List<SkillScore> sessionScores = const [],
}) {
  final quickHello = turnCount < 3;

  final locationById =
      <String, ({GardenStep step, int stepIndex, int skillIndex})>{};
  for (var stepIndex = 0; stepIndex < after.steps.length; stepIndex++) {
    final step = after.steps[stepIndex];
    for (var skillIndex = 0; skillIndex < step.skills.length; skillIndex++) {
      locationById[step.skills[skillIndex].id] = (
        step: step,
        stepIndex: stepIndex,
        skillIndex: skillIndex,
      );
    }
  }

  ({GardenStep step, int stepIndex, int skillIndex})? resolved;
  for (final skillId in {...aimedAt, ...fallbackSkillIds}) {
    final location = locationById[skillId];
    if (location != null) {
      resolved = location;
      break;
    }
  }

  if (quickHello) {
    // The quick-hello card is skill-agnostic; any anchor works. Fall back to the
    // first skill in the garden when nothing was aimed at / resolvable.
    final anchor = resolved ?? _firstSkillLocation(after);
    if (anchor == null) return null;
    final skill = anchor.step.skills[anchor.skillIndex];
    final stage = gardenGrowthStageFor(
      status: skill.status,
      sightings: skill.sightings,
    );
    return GardenGrowthRevealItem(
      step: anchor.step,
      skill: skill,
      stepIndex: anchor.stepIndex,
      skillIndex: anchor.skillIndex,
      fromStage: stage,
      toStage: stage,
      wateringOnly: true,
      quickHello: true,
    );
  }

  resolved ??= _fallbackWateringLocation(after);
  if (resolved == null) return null;
  final skill = resolved.step.skills[resolved.skillIndex];
  final stage = gardenGrowthStageFor(
    status: skill.status,
    sightings: skill.sightings,
  );
  return GardenGrowthRevealItem(
    step: resolved.step,
    skill: skill,
    stepIndex: resolved.stepIndex,
    skillIndex: resolved.skillIndex,
    fromStage: stage,
    toStage: stage,
    wateringOnly: true,
    evidence: _bestSessionEvidenceFor(sessionScores),
  );
}

({GardenStep step, int stepIndex, int skillIndex})? _fallbackWateringLocation(
  GardenData after,
) {
  if (after.steps.isEmpty) return null;
  final activeIndex = after.activeStepIndex.clamp(0, after.steps.length - 1);
  final activeStep = after.steps[activeIndex];
  for (
    var skillIndex = 0;
    skillIndex < activeStep.skills.length;
    skillIndex++
  ) {
    if (activeStep.skills[skillIndex].status != SkillStatus.owned) {
      return (step: activeStep, stepIndex: activeIndex, skillIndex: skillIndex);
    }
  }
  for (var stepIndex = 0; stepIndex < after.steps.length; stepIndex++) {
    final step = after.steps[stepIndex];
    for (var skillIndex = 0; skillIndex < step.skills.length; skillIndex++) {
      if (step.skills[skillIndex].status != SkillStatus.owned) {
        return (step: step, stepIndex: stepIndex, skillIndex: skillIndex);
      }
    }
  }
  return _firstSkillLocation(after);
}

({GardenStep step, int stepIndex, int skillIndex})? _firstSkillLocation(
  GardenData after,
) {
  for (var stepIndex = 0; stepIndex < after.steps.length; stepIndex++) {
    final step = after.steps[stepIndex];
    if (step.skills.isNotEmpty) {
      return (step: step, stepIndex: stepIndex, skillIndex: 0);
    }
  }
  return null;
}

int _inferredPreviousSightings(int sightings) {
  final capped = sightings >= 3 ? 3 : sightings;
  if (capped <= 0) return 0;
  return capped - 1;
}

SkillStatus _statusForInferredSightings(int sightings) {
  if (sightings >= 3) return SkillStatus.owned;
  if (sightings >= 1) return SkillStatus.emerging;
  return SkillStatus.locked;
}

GardenEvidence? _growthEvidenceFor(GardenSkill? before, GardenSkill after) {
  final beforeQuotes = {
    for (final evidence in before?.evidence ?? const <GardenEvidence>[])
      evidence.quote.trim(),
  };
  final newEvidence = after.evidence
      .where(
        (evidence) =>
            evidence.quote.trim().isNotEmpty &&
            !beforeQuotes.contains(evidence.quote.trim()),
      )
      .toList(growable: false);
  if (newEvidence.isNotEmpty) return newEvidence.first;

  final existing = after.evidence
      .where((evidence) => evidence.quote.trim().isNotEmpty)
      .toList(growable: false);
  if (existing.isEmpty) return null;
  return existing.last;
}

GardenEvidence? _bestSessionEvidenceFor(List<SkillScore> scores) {
  SkillScore? best;
  for (final score in scores) {
    if (score.evidence.trim().isEmpty) continue;
    if (best == null || score.confidence > best.confidence) best = score;
  }
  return _evidenceFromScore(best);
}

GardenEvidence? _evidenceFromScore(SkillScore? score) {
  if (score == null || score.evidence.trim().isEmpty) return null;
  return GardenEvidence(
    quote: score.evidence.trim(),
    confidence: score.confidence,
    prompted: score.prompted,
  );
}

final gardenPreviewEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('GARDEN_PREVIEW'),
);

final gardenPreviewControllerProvider =
    StateNotifierProvider<GardenPreviewController, GardenData>(
      (ref) => GardenPreviewController(),
    );

final gardenProvider = FutureProvider.autoDispose<GardenData>((ref) async {
  if (ref.watch(gardenPreviewEnabledProvider)) {
    return ref.watch(gardenPreviewControllerProvider);
  }
  final api = ref.read(ellaApiServiceProvider);
  return api.getGarden();
});

class GardenPreviewLevel {
  final String code;
  final String label;

  const GardenPreviewLevel(this.code, this.label);
}

class GardenPreviewController extends StateNotifier<GardenData> {
  String _level = gardenPreviewLevels.first.code;
  int _growthSightings = 0;
  int _growthCycle = 0;
  int _twoSkillGrowthSightings = 0;
  int _twoSkillGrowthCycle = 0;

  GardenPreviewController()
    : super(
        _buildPreviewGarden(
          level: gardenPreviewLevels.first.code,
          growthSightings: 0,
          growthCycle: 0,
          twoSkillGrowthSightings: 0,
          twoSkillGrowthCycle: 0,
        ),
      );

  void selectLevel(String level) {
    if (!_isPreviewLevel(level)) return;
    _level = level;
    _growthSightings = 0;
    _growthCycle++;
    _twoSkillGrowthSightings = 0;
    _twoSkillGrowthCycle++;
    _refresh();
  }

  void triggerGrowth() {
    if (_growthSightings >= 3) {
      _growthCycle++;
      _growthSightings = 1;
    } else {
      _growthSightings++;
    }
    _refresh();
  }

  void triggerTwoSkillsGrowth() {
    if (_twoSkillGrowthSightings >= 3) {
      _twoSkillGrowthCycle++;
      _twoSkillGrowthSightings = 1;
    } else {
      _twoSkillGrowthSightings++;
    }
    _refresh();
  }

  void _refresh() {
    state = _buildPreviewGarden(
      level: _level,
      growthSightings: _growthSightings,
      growthCycle: _growthCycle,
      twoSkillGrowthSightings: _twoSkillGrowthSightings,
      twoSkillGrowthCycle: _twoSkillGrowthCycle,
    );
  }
}

bool _isPreviewLevel(String level) =>
    gardenPreviewLevels.any((entry) => entry.code == level);

String _previewLabelFor(String level) => gardenPreviewLevels
    .firstWhere(
      (entry) => entry.code == level,
      orElse: () => gardenPreviewLevels.first,
    )
    .label;

GardenData _buildPreviewGarden({
  required String level,
  required int growthSightings,
  required int growthCycle,
  required int twoSkillGrowthSightings,
  required int twoSkillGrowthCycle,
}) {
  final label = _previewLabelFor(level);
  return GardenData(
    level: level,
    levelLabel: label,
    theme: label,
    activeStepIndex: 2,
    recommendedTopic: 'Preview practice',
    steps: [
      _previewStep(
        step: 1,
        name: 'Finding Better Words',
        skills: [
          _previewSkill(
            id: 'preview-growth-c$growthCycle',
            strand: Strand.voc,
            text: 'Use a more precise word',
            sightings: growthSightings,
          ),
          _previewSkill(
            id: 'preview-u1-s1',
            strand: Strand.gra,
            text: 'Use simple past tense',
            sightings: 1,
          ),
          _previewSkill(
            id: 'preview-u1-s2',
            strand: Strand.flu,
            text: 'Answer in a full sentence',
            sightings: 2,
          ),
          _previewSkill(
            id: 'preview-u1-s3',
            strand: Strand.voc,
            text: 'Describe a place clearly',
            sightings: 3,
          ),
        ],
      ),
      _previewStep(
        step: 2,
        name: 'Telling A Short Story',
        skills: [
          _previewSkill(
            id: 'preview-two-a-c$twoSkillGrowthCycle',
            strand: Strand.flu,
            text: 'Connect two ideas',
            sightings: twoSkillGrowthSightings,
          ),
          _previewSkill(
            id: 'preview-u2-s1',
            strand: Strand.voc,
            text: 'Use feeling words',
            sightings: 1,
          ),
          _previewSkill(
            id: 'preview-u2-s2',
            strand: Strand.gra,
            text: 'Use because correctly',
            sightings: 2,
          ),
          _previewSkill(
            id: 'preview-u2-s3',
            strand: Strand.flu,
            text: 'Speak without long pauses',
            sightings: 3,
          ),
          _previewSkill(
            id: 'preview-u2-s4',
            strand: Strand.voc,
            text: 'Choose a stronger verb',
            sightings: 4,
          ),
        ],
      ),
      _previewStep(
        step: 3,
        name: 'Asking Better Questions',
        skills: [
          _previewSkill(
            id: 'preview-u3-s0',
            strand: Strand.gra,
            text: 'Start questions with did',
            sightings: 0,
          ),
          _previewSkill(
            id: 'preview-u3-s1',
            strand: Strand.flu,
            text: 'Ask a follow-up question',
            sightings: 1,
          ),
          _previewSkill(
            id: 'preview-u3-s2',
            strand: Strand.voc,
            text: 'Use topic words',
            sightings: 2,
          ),
        ],
      ),
      _previewStep(
        step: 4,
        name: 'Explaining Your Opinion',
        skills: [
          _previewSkill(
            id: 'preview-u4-s0',
            strand: Strand.voc,
            text: 'Use opinion phrases',
            sightings: 1,
          ),
          _previewSkill(
            id: 'preview-u4-s1',
            strand: Strand.gra,
            text: 'Use comparatives',
            sightings: 2,
          ),
          _previewSkill(
            id: 'preview-u4-s2',
            strand: Strand.flu,
            text: 'Give a reason',
            sightings: 3,
          ),
          _previewSkill(
            id: 'preview-two-b-c$twoSkillGrowthCycle',
            strand: Strand.gra,
            text: 'Use but for contrast',
            sightings: twoSkillGrowthSightings,
          ),
        ],
      ),
      _previewStep(
        step: 5,
        name: 'Making A Clear Plan',
        skills: [
          _previewSkill(
            id: 'preview-u5-s0',
            strand: Strand.flu,
            text: 'Sequence steps clearly',
            sightings: 2,
          ),
          _previewSkill(
            id: 'preview-u5-s1',
            strand: Strand.voc,
            text: 'Use time words',
            sightings: 3,
          ),
          _previewSkill(
            id: 'preview-u5-s2',
            strand: Strand.gra,
            text: 'Use going to',
            sightings: 1,
          ),
          _previewSkill(
            id: 'preview-u5-s3',
            strand: Strand.voc,
            text: 'Name the next action',
            sightings: 0,
          ),
          _previewSkill(
            id: 'preview-u5-s4',
            strand: Strand.flu,
            text: 'Finish with confidence',
            sightings: 4,
          ),
        ],
      ),
    ],
  );
}

GardenStep _previewStep({
  required int step,
  required String name,
  required List<GardenSkill> skills,
}) => GardenStep(
  step: step,
  name: name,
  focus: 'Preview',
  isCompleted: step < 3,
  skills: skills,
);

GardenSkill _previewSkill({
  required String id,
  required Strand strand,
  required String text,
  required int sightings,
}) => GardenSkill(
  id: id,
  strand: strand,
  text: text,
  status: _previewStatusFor(sightings),
  sightings: sightings,
  evidence: _previewEvidenceFor(text, sightings),
);

SkillStatus _previewStatusFor(int sightings) {
  if (sightings >= 3) return SkillStatus.owned;
  if (sightings >= 1) return SkillStatus.emerging;
  return SkillStatus.locked;
}

List<GardenEvidence> _previewEvidenceFor(String text, int sightings) => [
  for (var i = 0; i < sightings.clamp(0, 3); i++)
    GardenEvidence(
      quote: switch (i) {
        0 => 'I can ${text.toLowerCase()}.',
        1 => 'Then I tried it again with more detail.',
        _ => 'Now it feels easy when I talk.',
      },
      confidence: 0.72 + i * 0.08,
      prompted: i == 0,
      topic: 'Preview conversation',
      createdAt: DateTime(2026, 7, 1 + i),
    ),
];
