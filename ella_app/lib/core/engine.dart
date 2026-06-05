// Deterministic ELLA engine — pure Dart, zero Flutter/network imports.
// Every decision about owned / emerging / due_next comes from functions in this file.
// No LLM ever writes state. This is the one non-negotiable principle.
//
// Port of ella-loop-sim-2.html functions:
//   applyMerge · dueSkill · dueUnit · unitComplete · activeStep
//   pickTopic · targetsListFor · buildConvPrompt · buildJudgePrompt

import 'dart:math';

import 'constants.dart';
import 'prompts.dart';
import 'skill_data.dart';
import 'topic_data.dart';
import '../models/child_memory.dart';

// ── Result types ─────────────────────────────────────────────────────────────

class MergeResult {
  final MemoryState mem;
  final List<StateChange> changes;
  const MergeResult({required this.mem, required this.changes});
}

class SkillTarget {
  final String id;
  final String why;
  const SkillTarget({required this.id, required this.why});
}

class DueUnitResult {
  final UnitStep? step;
  final List<SkillTarget> picks;
  const DueUnitResult({this.step, this.picks = const []});
}

// ── Private helpers ──────────────────────────────────────────────────────────

// Works on MemoryState (read path).
String bucketOf(MemoryState mem, String id) {
  if (mem.owned.contains(id)) return 'owned';
  if (mem.emerging.contains(id)) return 'emerging';
  return 'locked';
}

// Works on mutable working copies (write path inside applyMerge).
String _bucketFromLists(List<String> owned, List<String> emerging, String id) {
  if (owned.contains(id)) return 'owned';
  if (emerging.contains(id)) return 'emerging';
  return 'locked';
}

const Map<String, String> _strandLabels = {'VOC': 'Vocabulary', 'GRA': 'Grammar', 'FLU': 'Fluency'};

// ── applyMerge ───────────────────────────────────────────────────────────────
//
// Exact port of the simulator's applyMerge(mem, scores, level).
// For each judged skill:
//   • c < FLOOR            → no change
//   • locked               → emerging  (any evidence ≥ FLOOR)
//   • emerging, sightings≥2 or effort-path → owned
// Effort path (A1/A2 only): strength + sightings ≥ 3  AND  c ≥ FLOOR
//
// Returns new MemoryState and a list of state changes.
// No demotion (decay is a future feature).
MergeResult applyMerge(MemoryState mem, List<SkillScore> scores, String level) {
  final sightings = Map<String, int>.from(mem.sightings);
  final strength = Map<String, int>.from(mem.strength);
  final lastSeen = Map<String, String>.from(mem.lastSeen);
  final owned = List<String>.from(mem.owned);
  final emerging = List<String>.from(mem.emerging);

  final changes = <StateChange>[];
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final bar = ownBarFor(level);

  for (final sc in scores) {
    final prior = _bucketFromLists(owned, emerging, sc.id);
    final qualifies = sc.confidence >= bar;

    // Increment counters for any evidence ≥ FLOOR
    if (sc.confidence >= kFloor) {
      lastSeen[sc.id] = today;
      if (qualifies) sightings[sc.id] = (sightings[sc.id] ?? 0) + 1;
      if (!sc.prompted) strength[sc.id] = (strength[sc.id] ?? 0) + 1;
    }

    // Read post-increment values for the promotion check
    final currentSightings = sightings[sc.id] ?? 0;
    final effortPath = (level == 'A1' || level == 'A2') &&
        (strength[sc.id] ?? 0) + (sightings[sc.id] ?? 0) >= 3 &&
        sc.confidence >= kFloor;

    var next = prior;
    if (sc.confidence < kFloor) {
      next = prior;
    } else if (prior == 'locked') {
      next = 'emerging';
    } else if (prior == 'emerging' &&
        (currentSightings >= kSightingsToOwn || effortPath)) {
      next = 'owned';
    }

    if (next != prior) {
      changes.add(StateChange(id: sc.id, from: prior, to: next));
      if (prior == 'locked') {
        emerging.add(sc.id);
      } else if (prior == 'emerging' && next == 'owned') {
        emerging.remove(sc.id);
        owned.add(sc.id);
      }
    }
  }

  return MergeResult(
    mem: mem.copyWith(
      sightings: sightings,
      strength: strength,
      lastSeen: lastSeen,
      owned: owned,
      emerging: emerging,
    ),
    changes: changes,
  );
}

// ── dueSkill ─────────────────────────────────────────────────────────────────
//
// Targeting for micro-skill mode.
// Returns up to 3 picks: [emerging, weakest-locked, familiar-owned].
List<SkillTarget> dueSkill(MemoryState mem, String level) {
  final levelSkills = skillsAtLevel(level);
  final levelIds = levelSkills.map((s) => s.id).toSet();
  final picks = <SkillTarget>[];

  // 1. First emerging skill at this level
  final em = mem.emerging.firstWhere(
    (id) => levelIds.contains(id),
    orElse: () => '',
  );
  if (em.isNotEmpty) {
    picks.add(SkillTarget(id: em, why: 'finish what is started (emerging)'));
  }

  // 2. Count owned per strand at this level
  final strandOwned = <String, int>{'VOC': 0, 'GRA': 0, 'FLU': 0};
  for (final id in mem.owned) {
    final s = kFlatSkillsById[id];
    if (s != null && s.level == level) {
      strandOwned[s.strand] = (strandOwned[s.strand] ?? 0) + 1;
    }
  }

  // Sort strands by owned count ascending (weakest first)
  final order = ['VOC', 'GRA', 'FLU']
    ..sort((a, b) => (strandOwned[a] ?? 0).compareTo(strandOwned[b] ?? 0));

  // 3. First locked skill in the weakest strand (not already picked)
  final pickedIds = picks.map((p) => p.id).toSet();
  for (final strand in order) {
    final locked = levelSkills.firstWhere(
      (s) =>
          s.strand == strand &&
          _bucketFromLists(mem.owned, mem.emerging, s.id) == 'locked' &&
          !pickedIds.contains(s.id),
      orElse: () => const SkillDef(id: '', strand: 'VOC', text: ''),
    );
    if (locked.id.isNotEmpty) {
      picks.add(SkillTarget(
        id: locked.id,
        why: 'open weakest strand: ${_strandLabels[strand] ?? strand}',
      ));
      break;
    }
  }

  // 4. First owned skill at this level as "familiar" (not already picked)
  final updatedPickedIds = picks.map((p) => p.id).toSet();
  final fav = mem.owned.firstWhere(
    (id) => levelIds.contains(id) && !updatedPickedIds.contains(id),
    orElse: () => '',
  );
  if (fav.isNotEmpty) {
    picks.add(SkillTarget(id: fav, why: 'familiar favourite (owned)'));
  }

  return picks;
}

// ── unitComplete ─────────────────────────────────────────────────────────────
//
// FLU + VOC must be owned; GRA must be at least emerging (not locked).
bool unitComplete(MemoryState mem, UnitStep unit) {
  for (final s in unit.skills) {
    final b = bucketOf(mem, s.id);
    if ((s.strand == 'FLU' || s.strand == 'VOC') && b != 'owned') return false;
    if (s.strand == 'GRA' && b == 'locked') return false;
  }
  return true;
}

// ── activeStep ───────────────────────────────────────────────────────────────
//
// Returns first incomplete unit step, or null when all 5 are done.
UnitStep? activeStep(MemoryState mem) {
  for (final u in kUnitSteps) {
    if (!unitComplete(mem, u)) return u;
  }
  return null;
}

// ── dueUnit ──────────────────────────────────────────────────────────────────
//
// Targeting for unit mode.
// Returns all unowned skills in the active step, sorted FLU → VOC → GRA.
DueUnitResult dueUnit(MemoryState mem) {
  final u = activeStep(mem);
  if (u == null) return const DueUnitResult();

  int rank(String strand) => strand == 'FLU' ? 0 : strand == 'VOC' ? 1 : 2;

  final sorted = [...u.skills]
    ..sort((a, b) => rank(a.strand).compareTo(rank(b.strand)));

  final picks = sorted
      .where((s) => bucketOf(mem, s.id) != 'owned')
      .map((s) => SkillTarget(id: s.id, why: 'unit "${u.name}" · ${s.strand}'))
      .toList();

  return DueUnitResult(step: u, picks: picks);
}

// ── targetsListFor ───────────────────────────────────────────────────────────
//
// Computes due_next from current memory. Call after every applyMerge.
DueNext targetsListFor(MemoryState mem, String progressionModel, String level) {
  final List<String> picks;
  if (progressionModel == 'units') {
    picks = dueUnit(mem).picks.map((p) => p.id).toList();
  } else {
    picks = dueSkill(mem, level).map((p) => p.id).toList();
  }
  return DueNext(
    primary: picks.isNotEmpty ? picks.first : null,
    watching: picks.length > 1 ? picks.sublist(1) : const [],
  );
}

// ── pickTopic ────────────────────────────────────────────────────────────────
//
// Level-appropriate topic, excluding last 5, lightly matched to interests.
// Falls back to random within level if all recently used.
Topic? pickTopic(MemoryState mem) {
  final bank = kTopics[mem.level] ?? kTopics['A1'] ?? [];
  if (bank.isEmpty) return null;

  final fresh = bank.where((t) => !mem.lastTopics.contains(t.topic)).toList();
  final pool = fresh.isNotEmpty ? fresh : List<Topic>.from(bank);

  final interests = mem.interests.toLowerCase();
  if (interests.isNotEmpty) {
    final match = pool.firstWhere(
      (t) {
        final firstWord = t.topic.toLowerCase().split(' ').first;
        return interests.contains(firstWord) ||
            interests.contains(t.theme.toLowerCase());
      },
      orElse: () => const Topic(level: '', theme: '', topic: '', starters: ''),
    );
    if (match.topic.isNotEmpty) return match;
  }

  return pool[Random().nextInt(pool.length)];
}

// ── buildConvPrompt ──────────────────────────────────────────────────────────
//
// Assembles the full Zoe conversation prompt.
// Pass currentTopic separately — it is transient and not stored in memory_state.
String buildConvPrompt({
  required MemoryState mem,
  required String progressionModel,
  required String level,
  required List<ConvMessage> history,
  required AppPrompts prompts,
  Topic? currentTopic,
}) {
  final targets = mem.dueNext.flat;
  final primary = targets.isNotEmpty ? targets.first : null;
  final watching = targets.length > 1 ? targets.sublist(1) : <String>[];

  final primaryLine = primary != null
      ? 'PRIMARY skill to steer toward: $primary — ${skillText(primary)}'
      : 'PRIMARY: keep them talking';
  final watchLine = watching.isNotEmpty
      ? '\nAlso fine if these come up: ${watching.map((id) => '$id (${skillText(id)})').join('; ')}'
      : '';
  final topicLine = currentTopic != null
      ? "\nTODAY'S TOPIC: \"${currentTopic.topic}\" (${currentTopic.theme}). Openers you can adapt: ${currentTopic.starters}"
      : '';

  final String frame;
  if (progressionModel == 'units') {
    final u = activeStep(mem);
    frame = prompts.convUnit
        .replaceAll('{{UNITNAME}}', u?.name ?? '(complete)')
        .replaceAll('{{UNITFOCUS}}', u?.focus ?? '')
        .replaceAll('{{TARGETS}}', primaryLine + watchLine);
  } else {
    frame = prompts.convSkill.replaceAll('{{TARGETS}}', primaryLine + watchLine);
  }

  final profile =
      (level == 'A1' || level == 'A2') ? prompts.profileA1 : prompts.profileB1;

  final convo = history
      .where((m) => m.role != 'sys')
      .map((m) => '${m.role == 'zoe' ? 'Zoe' : 'Learner'}: ${m.text}')
      .join('\n');

  final interestLine =
      mem.interests.isNotEmpty ? '\nLEARNER INTERESTS: ${mem.interests}' : '';
  final recentLine = mem.lastTopics.isNotEmpty
      ? '\nRECENT TOPICS (avoid repeating): ${mem.lastTopics.join(', ')}'
      : '';

  return '${prompts.base}\n\n$profile\n\n$frame$topicLine$interestLine$recentLine\n\n'
      'CONVERSATION SO FAR:\n${convo.isEmpty ? '(none — you open)' : convo}\n\n'
      "Reply with ONLY Zoe's next short spoken turn.";
}

// ── buildJudgePrompt ─────────────────────────────────────────────────────────
String buildJudgePrompt({
  required String level,
  required List<String> skillIds,
  required List<ConvMessage> history,
  required AppPrompts prompts,
}) {
  final idList = skillIds.map((id) => '- $id: ${skillText(id)}').join('\n');
  final convo = history
      .where((m) => m.role != 'sys')
      .map((m) => '${m.role == 'zoe' ? 'Zoe' : 'Learner'}: ${m.text}')
      .join('\n');
  return '${prompts.judge}\n\nLEARNER LEVEL: $level\n\nTARGET SKILLS:\n$idList\n\nTRANSCRIPT:\n$convo';
}

// ── applyEndChat ─────────────────────────────────────────────────────────────
//
// Combines the post-judge steps from the simulator's endChat():
//   bump effort, record topic, refresh due_next.
// Call AFTER applyMerge; pass its MergeResult here.
MemoryState applyEndChat({
  required MemoryState mem,
  required MergeResult mergeResult,
  required int turnCount,
  required int chatNumber,
  required Topic? usedTopic,
  required String progressionModel,
  required String level,
}) {
  var updated = mergeResult.mem.copyWith(
    effortTimesSpoken: mem.effortTimesSpoken + turnCount,
    updatedAfterChat: chatNumber,
  );

  if (usedTopic != null) {
    final newTopics =
        [usedTopic.topic, ...updated.lastTopics].take(5).toList();
    updated = updated.copyWith(lastTopics: newTopics);
  }

  final newDueNext = targetsListFor(updated, progressionModel, level);
  return updated.copyWith(dueNext: newDueNext);
}
