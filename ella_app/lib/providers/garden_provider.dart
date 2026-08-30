// Garden data provider — fetches GET /users/me/garden via the Ella API.
// Auth token is managed by EllaApiService via SharedPreferences. Refreshable so the
// Garden tab can pull fresh state after a session ends.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/child_memory.dart';
import '../models/garden.dart';
import '../services/ella_api_service.dart';
import 'service_providers.dart';

/// A garden level: CEFR code plus its display name.
class GardenLevel {
  final String code;
  final String label;

  const GardenLevel(this.code, this.label);
}

/// Canonical ordered garden sequence (A0 → C1). Used by the garden switcher
/// sheet and the level index helpers.
const List<GardenLevel> gardenSequence = [
  GardenLevel('A0', 'Dawn Glade'),
  GardenLevel('A1', 'Morning Meadow'),
  GardenLevel('A2', 'Midday Grove'),
  GardenLevel('B1', 'Golden Orchard'),
  GardenLevel('B2', 'Twilight Valley'),
  GardenLevel('C1', 'Starlight Summit'),
];

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
/// An unknown/absent level falls back to the first entry in the sequence.
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

/// A single one-shot "has this student seen X" flag, scoped by the signed-in
/// user id so it survives app restarts but never leaks across accounts on a
/// shared device. Same [SharedPreferences] scoping as
/// [CompletedGardenIntroSeenController], just without the per-level set.
class OneShotSeenController extends StateNotifier<bool> {
  final String _prefsKeyPrefix;

  OneShotSeenController(this._prefsKeyPrefix) : super(false) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_completedGardenIntroUserIdPrefsKey)?.trim();
    final scopedUserId = userId == null || userId.isEmpty
        ? 'anonymous'
        : userId;
    final seen = prefs.getBool('$_prefsKeyPrefix:$scopedUserId') ?? false;
    if (!mounted) return;
    state = seen;
  }

  Future<void> markSeen() async {
    if (state) return;
    state = true;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_completedGardenIntroUserIdPrefsKey)?.trim();
    final scopedUserId = userId == null || userId.isEmpty
        ? 'anonymous'
        : userId;
    await prefs.setBool('$_prefsKeyPrefix:$scopedUserId', true);
  }
}

/// Gates the one-time "You've got a spot" early-access welcome screen shown
/// right after login, before name/age onboarding (see RootGate in app.dart).
final spotAccessSeenProvider =
    StateNotifierProvider<OneShotSeenController, bool>(
      (ref) => OneShotSeenController('ella_spot_access_seen_v1'),
    );

String _canonicalGardenLevel(String level) {
  final upper = level.trim().toUpperCase();
  return gardenSequence.any((entry) => entry.code == upper)
      ? upper
      : gardenSequence.first.code;
}

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

/// Growth stage follows sightings alone, matching the plot art
/// (1 → seedling, 2 → young, ≥3 → bloom).
GardenGrowthStage gardenGrowthStageFor(int sightings) => switch (sightings) {
  >= 3 => GardenGrowthStage.bloomed,
  2 => GardenGrowthStage.budding,
  1 => GardenGrowthStage.sprout,
  _ => GardenGrowthStage.seed,
};

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
      final fromStage = gardenGrowthStageFor(beforeSightings);
      final toStage = gardenGrowthStageFor(afterSightings);
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

List<GardenGrowthRevealItem> buildGardenGrowthRevealItems({
  required GardenData? before,
  required GardenData after,
}) {
  if (before == null) return const [];

  final beforeById = <String, GardenSkill>{};
  for (final step in before.steps) {
    for (final skill in step.skills) {
      beforeById[skill.id] = skill;
    }
  }

  final items = <GardenGrowthRevealItem>[];
  for (var stepIndex = 0; stepIndex < after.steps.length; stepIndex++) {
    final step = after.steps[stepIndex];
    for (var skillIndex = 0; skillIndex < step.skills.length; skillIndex++) {
      final skill = step.skills[skillIndex];
      final previous = beforeById[skill.id];
      if (previous == null || skill.sightings <= previous.sightings) continue;

      final fromStage = gardenGrowthStageFor(previous.sightings);
      final toStage = gardenGrowthStageFor(skill.sightings);
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
    final stage = gardenGrowthStageFor(skill.sightings);
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
  final stage = gardenGrowthStageFor(skill.sightings);
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

final gardenProvider = FutureProvider.autoDispose<GardenData>((ref) async {
  final api = ref.read(ellaApiServiceProvider);
  return api.getGarden();
});

/// Real garden data for a previously completed level —
/// GET /users/me/garden?level=<code>. Throws when the backend doesn't honour
/// the level param (echoes another level back) or returns no units, so
/// callers fall back to [completedPreviousGardenData].
final previousGardenProvider = FutureProvider.autoDispose
    .family<GardenData, String>((ref, level) async {
      final api = ref.read(ellaApiServiceProvider);
      final garden = await api.getGarden(level: level);
      final requested = level.trim().toUpperCase();
      if (garden.level.trim().toUpperCase() != requested ||
          garden.steps.isEmpty) {
        throw const EllaApiException('previous_garden_unavailable');
      }
      return garden;
    });
