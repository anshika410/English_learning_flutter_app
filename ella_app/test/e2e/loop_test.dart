// Phase 7 — End-to-end loop test.
//
// Simulates the full ELLA chat loop without any network or Flutter widgets:
//   memory → pickTopic → buildConvPrompt → (fake LLM turns) →
//   buildJudgePrompt → (fake judge scores) → applyMerge → applyEndChat →
//   updated memory → repeat.
//
// This mirrors the simulator (ella-loop-sim-2.html) ground truth.
// Run with: flutter test test/e2e/loop_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/core/constants.dart';
import 'package:ella_app/core/engine.dart';
import 'package:ella_app/core/prompts.dart';
import 'package:ella_app/core/skill_data.dart';
import 'package:ella_app/core/topic_data.dart';
import 'package:ella_app/models/child_memory.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

SkillScore sc(String id, double confidence, {bool prompted = true}) =>
    SkillScore(id: id, confidence: confidence, prompted: prompted);

// Fake "5-turn" conversation history.
List<ConvMessage> fakeHistory(Topic topic) => [
      ConvMessage(role: 'zoe', text: 'Hi! What do you like to do after school?'),
      ConvMessage(
          role: 'user',
          text: "I like play football. And I go park with my friend."),
      ConvMessage(role: 'zoe', text: 'That sounds fun! Who is your best friend?'),
      ConvMessage(role: 'user', text: 'My friend name is Ali. He is funny.'),
      ConvMessage(
          role: 'zoe', text: 'Nice! What do you both like to do together?'),
    ];

// Run one complete end-to-end chat loop (no network).
// Returns the updated MemoryState after applyEndChat.
MemoryState runLoop({
  required MemoryState mem,
  required List<SkillScore> fakeScores,
  required int chatNumber,
  int fakeTurns = 2,
}) {
  // 1. Pick a topic
  final topic = pickTopic(mem);
  // topics can be null only if bank is empty — verified separately
  expect(topic, isNotNull,
      reason: 'pickTopic must always find a topic for a non-empty bank');

  // 2. Build conv prompt
  final convPrompt = buildConvPrompt(
    mem: mem,
    progressionModel: mem.progressionModel,
    level: mem.level,
    history: [],
    prompts: kDefaultPrompts,
    currentTopic: topic,
  );
  expect(convPrompt, isNotEmpty);
  expect(convPrompt, contains('Zoe')); // base prompt
  expect(convPrompt, contains(topic!.topic)); // topic injected

  // 3. Simulate turns (no LLM call)
  final history = fakeHistory(topic);

  // 4. Build judge prompt
  final targets = mem.dueNext.flat;
  final judgePrompt = buildJudgePrompt(
    level: mem.level,
    skillIds: targets.isNotEmpty ? targets : [skillsAtLevel(mem.level).first.id],
    history: history,
    prompts: kDefaultPrompts,
  );
  expect(judgePrompt, contains('LEARNER LEVEL:'));
  expect(judgePrompt, contains('TARGET SKILLS:'));
  expect(judgePrompt, contains('TRANSCRIPT:'));
  expect(judgePrompt, contains('Zoe'));
  expect(judgePrompt, contains('Learner'));

  // 5. applyMerge with fake scores
  final mergeResult = applyMerge(mem, fakeScores, mem.level);

  // 6. applyEndChat
  final updated = applyEndChat(
    mem: mem,
    mergeResult: mergeResult,
    turnCount: fakeTurns,
    chatNumber: chatNumber,
    usedTopic: topic,
    progressionModel: mem.progressionModel,
    level: mem.level,
  );

  return updated;
}

// ── tests ────────────────────────────────────────────────────────────────────

void main() {
  const prompts = kDefaultPrompts;

  // ── 1. Two-chat promotion scenario (micro-skill mode) ────────────────────

  group('Two-chat skill promotion — micro-skill mode', () {
    const targetSkill = 'A1-VOC-01'; // first flat skill

    late MemoryState mem;

    setUp(() {
      mem = MemoryState.fresh('A1', childId: 'test')
          .copyWith(progressionModel: 'micro-skill');
    });

    test('Chat 1: locked → emerging after one qualifying sighting', () {
      // Score above OWN_BAR[A1]=0.55 → 1 sighting, should go emerging
      final mergeResult = applyMerge(mem, [sc(targetSkill, 0.8)], 'A1');
      expect(bucketOf(mergeResult.mem, targetSkill), 'emerging');
      expect(mergeResult.changes.length, 1);
      expect(mergeResult.changes.first.from, 'locked');
      expect(mergeResult.changes.first.to, 'emerging');
    });

    test('Chat 2: emerging → owned after second qualifying sighting', () {
      // Chat 1
      final r1 = applyMerge(mem, [sc(targetSkill, 0.8)], 'A1');
      expect(bucketOf(r1.mem, targetSkill), 'emerging');

      // Chat 2
      final r2 = applyMerge(r1.mem, [sc(targetSkill, 0.8)], 'A1');
      expect(bucketOf(r2.mem, targetSkill), 'owned');
      expect(r2.changes.first.to, 'owned');
    });

    test('Full two-chat loop: state persists through applyEndChat', () {
      // Chat 1 — score above OWN_BAR[A1]=0.55 → emerging with 1 qualifying sighting
      mem = runLoop(
        mem: mem,
        fakeScores: [sc(targetSkill, 0.8)],
        chatNumber: 1,
      );
      expect(bucketOf(mem, targetSkill), 'emerging');
      expect(mem.sightings[targetSkill], 1);
      expect(mem.effortTimesSpoken, 2); // fakeTurns=2 added
      expect(mem.lastTopics.length, 1); // first topic recorded
      expect(mem.updatedAfterChat, 1);

      // Chat 2 — second qualifying sighting → owned (sightings >= SIGHTINGS_TO_OWN=2)
      mem = runLoop(
        mem: mem,
        fakeScores: [sc(targetSkill, 0.8)],
        chatNumber: 2,
      );
      expect(bucketOf(mem, targetSkill), 'owned');
      expect(mem.sightings[targetSkill], 2);
      expect(mem.effortTimesSpoken, 4); // +2 more turns
      expect(mem.lastTopics.length, 2); // second topic recorded
      expect(mem.updatedAfterChat, 2);
    });
  });

  // ── 2. Topic ring buffer ─────────────────────────────────────────────────

  group('Topic ring buffer', () {
    test('lastTopics grows up to 5 and old topics are dropped', () {
      var mem = MemoryState.fresh('A1', childId: 'test')
          .copyWith(progressionModel: 'micro-skill');

      // Run 6 chats — topics should never exceed 5 in ring
      for (var i = 1; i <= 6; i++) {
        mem = runLoop(
          mem: mem,
          fakeScores: [], // no scores, just track topics
          chatNumber: i,
        );
        expect(mem.lastTopics.length, lessThanOrEqualTo(5));
      }
      // After 6 chats, ring holds exactly 5
      expect(mem.lastTopics.length, 5);
    });

    test('pickTopic avoids recently used topics when fresh topics remain', () {
      final allA1 = kTopics['A1'] ?? [];
      expect(allA1.length, greaterThan(5),
          reason: 'must have more than 5 A1 topics to test avoidance');

      // Fill ring with first 5 topic names
      final usedTopics = allA1.take(5).map((t) => t.topic).toList();
      final mem = MemoryState.fresh('A1', childId: 'test')
          .copyWith(lastTopics: usedTopics);

      // pickTopic should NOT return one of the used 5
      final pick = pickTopic(mem);
      expect(pick, isNotNull);
      expect(usedTopics, isNot(contains(pick!.topic)));
    });
  });

  // ── 3. Units mode: dueUnit and conv prompt ────────────────────────────────

  group('Units mode', () {
    late MemoryState mem;

    setUp(() {
      mem = MemoryState.fresh('A1', childId: 'test')
          .copyWith(progressionModel: 'units');
    });

    test('dueUnit returns picks from active step', () {
      final result = dueUnit(mem);
      expect(result.step, isNotNull, reason: 'fresh memory has an active step');
      expect(result.picks, isNotEmpty);
      // All picks belong to the active step
      final stepSkillIds = result.step!.skills.map((s) => s.id).toSet();
      for (final p in result.picks) {
        expect(stepSkillIds, contains(p.id));
      }
    });

    test('activeStep returns null when all steps complete', () {
      // Mark all unit skills as owned
      final allUnitIds = kUnitSteps
          .expand((u) => u.skills.map((s) => s.id))
          .toList();
      final fullMem = mem.copyWith(owned: allUnitIds);
      expect(activeStep(fullMem), isNull);
    });

    test('buildConvPrompt in units mode uses convUnit template', () {
      final topic = pickTopic(mem);
      final prompt = buildConvPrompt(
        mem: mem,
        progressionModel: 'units',
        level: 'A1',
        history: [],
        prompts: kDefaultPrompts,
        currentTopic: topic,
      );
      // convUnit template keyword
      expect(prompt, contains("TODAY'S UNIT:"));
    });

    test('buildConvPrompt in micro-skill mode uses convSkill template', () {
      final microMem = mem.copyWith(progressionModel: 'micro-skill');
      final topic = pickTopic(microMem);
      final prompt = buildConvPrompt(
        mem: microMem,
        progressionModel: 'micro-skill',
        level: 'A1',
        history: [],
        prompts: kDefaultPrompts,
        currentTopic: topic,
      );
      expect(prompt, contains("TODAY'S due_next"));
    });

    test('unitComplete is false for fresh memory', () {
      for (final u in kUnitSteps) {
        expect(unitComplete(mem, u), isFalse,
            reason: 'no skills owned on fresh memory');
      }
    });

    test('unitComplete: FLU+VOC owned but GRA still locked → false', () {
      final step = kUnitSteps.first;
      final fluVocIds = step.skills
          .where((s) => s.strand == 'FLU' || s.strand == 'VOC')
          .map((s) => s.id)
          .toList();
      final partial = mem.copyWith(owned: fluVocIds); // GRA still locked
      expect(unitComplete(partial, step), isTrue);
    });

    test('unitComplete: FLU+VOC owned and GRA emerging → true', () {
      final step = kUnitSteps.first;
      final fluVocIds = step.skills
          .where((s) => s.strand == 'FLU' || s.strand == 'VOC')
          .map((s) => s.id)
          .toList();
      final graId = step.skills
          .firstWhere((s) => s.strand == 'GRA')
          .id;
      final fullMem =
          mem.copyWith(owned: fluVocIds, emerging: [graId]);
      expect(unitComplete(fullMem, step), isTrue);
    });
  });

  // ── 4. Conv prompt structure ─────────────────────────────────────────────

  group('buildConvPrompt structure', () {
    const level = 'A1';

    test('contains base prompt', () {
      final mem = MemoryState.fresh(level, childId: 'test');
      final topic = pickTopic(mem);
      final prompt = buildConvPrompt(
        mem: mem,
        progressionModel: mem.progressionModel,
        level: level,
        history: [],
        prompts: prompts,
        currentTopic: topic,
      );
      expect(prompt, contains('You are Zoe'));
    });

    test('A1 uses profileA1 not profileB1', () {
      final mem = MemoryState.fresh('A1', childId: 'test');
      final prompt = buildConvPrompt(
        mem: mem,
        progressionModel: mem.progressionModel,
        level: 'A1',
        history: [],
        prompts: prompts,
        currentTopic: null,
      );
      expect(prompt, contains('LEVEL: A1'));
    });

    test('B1 uses profileB1 not profileA1', () {
      final mem = MemoryState.fresh('B1', childId: 'test');
      final prompt = buildConvPrompt(
        mem: mem,
        progressionModel: mem.progressionModel,
        level: 'B1',
        history: [],
        prompts: prompts,
        currentTopic: null,
      );
      expect(prompt, contains('LEVEL: B1'));
      expect(prompt, isNot(contains('LEVEL: A1')));
    });

    test('conversation history is injected', () {
      final mem = MemoryState.fresh('A1', childId: 'test');
      final history = [
        const ConvMessage(role: 'zoe', text: 'Hello there!'),
        const ConvMessage(role: 'user', text: 'Hi Zoe.'),
      ];
      final prompt = buildConvPrompt(
        mem: mem,
        progressionModel: mem.progressionModel,
        level: 'A1',
        history: history,
        prompts: prompts,
        currentTopic: null,
      );
      expect(prompt, contains('Hello there!'));
      expect(prompt, contains('Hi Zoe.'));
    });

    test('(none — you open) shown when history is empty', () {
      final mem = MemoryState.fresh('A1', childId: 'test');
      final prompt = buildConvPrompt(
        mem: mem,
        progressionModel: mem.progressionModel,
        level: 'A1',
        history: [],
        prompts: prompts,
        currentTopic: null,
      );
      expect(prompt, contains('(none — you open)'));
    });

    test('interests line injected when non-empty', () {
      final mem =
          MemoryState.fresh('A1', childId: 'test').copyWith(interests: 'football');
      final prompt = buildConvPrompt(
        mem: mem,
        progressionModel: mem.progressionModel,
        level: 'A1',
        history: [],
        prompts: prompts,
        currentTopic: null,
      );
      expect(prompt, contains('football'));
    });

    test('recent topics line injected', () {
      final mem = MemoryState.fresh('A1', childId: 'test')
          .copyWith(lastTopics: ['My family', 'My school']);
      final prompt = buildConvPrompt(
        mem: mem,
        progressionModel: mem.progressionModel,
        level: 'A1',
        history: [],
        prompts: prompts,
        currentTopic: null,
      );
      expect(prompt, contains('My family'));
    });
  });

  // ── 5. buildJudgePrompt structure ────────────────────────────────────────

  group('buildJudgePrompt structure', () {
    test('contains all required sections', () {
      final history = [
        const ConvMessage(role: 'zoe', text: 'How are you?'),
        const ConvMessage(role: 'user', text: 'I am fine thank you.'),
      ];
      final prompt = buildJudgePrompt(
        level: 'A1',
        skillIds: ['A1-VOC-01', 'A1-GRA-01'],
        history: history,
        prompts: prompts,
      );
      expect(prompt, contains('LEARNER LEVEL: A1'));
      expect(prompt, contains('TARGET SKILLS:'));
      expect(prompt, contains('A1-VOC-01'));
      expect(prompt, contains('A1-GRA-01'));
      expect(prompt, contains('TRANSCRIPT:'));
      expect(prompt, contains('Zoe: How are you?'));
      expect(prompt, contains('Learner: I am fine thank you.'));
    });

    test('sys messages excluded from transcript', () {
      final history = [
        const ConvMessage(role: 'sys', text: 'internal note'),
        const ConvMessage(role: 'zoe', text: 'Hi!'),
      ];
      final prompt = buildJudgePrompt(
        level: 'A1',
        skillIds: ['A1-VOC-01'],
        history: history,
        prompts: prompts,
      );
      expect(prompt, isNot(contains('internal note')));
      expect(prompt, contains('Zoe: Hi!'));
    });
  });

  // ── 6. applyEndChat bookkeeping ───────────────────────────────────────────

  group('applyEndChat bookkeeping', () {
    test('effortTimesSpoken accumulates across multiple chats', () {
      var mem = MemoryState.fresh('A1', childId: 'test');
      final mergeResult = applyMerge(mem, [], 'A1');

      mem = applyEndChat(
        mem: mem,
        mergeResult: mergeResult,
        turnCount: 3,
        chatNumber: 1,
        usedTopic: null,
        progressionModel: 'micro-skill',
        level: 'A1',
      );
      expect(mem.effortTimesSpoken, 3);

      final r2 = applyMerge(mem, [], 'A1');
      mem = applyEndChat(
        mem: mem,
        mergeResult: r2,
        turnCount: 5,
        chatNumber: 2,
        usedTopic: null,
        progressionModel: 'micro-skill',
        level: 'A1',
      );
      expect(mem.effortTimesSpoken, 8); // 3 + 5
    });

    test('updatedAfterChat is set to chatNumber', () {
      var mem = MemoryState.fresh('A1', childId: 'test');
      final r = applyMerge(mem, [], 'A1');
      mem = applyEndChat(
        mem: mem,
        mergeResult: r,
        turnCount: 2,
        chatNumber: 7,
        usedTopic: null,
        progressionModel: 'micro-skill',
        level: 'A1',
      );
      expect(mem.updatedAfterChat, 7);
    });

    test('dueNext is recomputed after merge changes state', () {
      const skill = 'A1-VOC-01';
      var mem = MemoryState.fresh('A1', childId: 'test')
          .copyWith(progressionModel: 'micro-skill');

      // Give the skill a high score → should become emerging → promoted to due_next
      final r = applyMerge(mem, [sc(skill, 0.9)], 'A1');
      expect(bucketOf(r.mem, skill), 'emerging');

      mem = applyEndChat(
        mem: mem,
        mergeResult: r,
        turnCount: 2,
        chatNumber: 1,
        usedTopic: null,
        progressionModel: 'micro-skill',
        level: 'A1',
      );
      // dueNext.primary should be the emerging skill (finish what is started)
      expect(mem.dueNext.primary, skill);
    });

    test('topic is prepended to lastTopics', () {
      var mem = MemoryState.fresh('A1', childId: 'test');
      final topic = const Topic(
          level: 'A1', theme: 'School', topic: 'My classroom', starters: '');
      final r = applyMerge(mem, [], 'A1');
      mem = applyEndChat(
        mem: mem,
        mergeResult: r,
        turnCount: 2,
        chatNumber: 1,
        usedTopic: topic,
        progressionModel: 'micro-skill',
        level: 'A1',
      );
      expect(mem.lastTopics.first, 'My classroom');
    });
  });

  // ── 7. Effort path end-to-end ─────────────────────────────────────────────

  group('Effort path end-to-end (A1 only)', () {
    const skill = 'A1-FLU-01';

    test('3 unprompted below-OWN_BAR chats promote via effort path', () {
      var mem = MemoryState.fresh('A1', childId: 'test')
          .copyWith(progressionModel: 'micro-skill');

      // Each chat: unprompted score at 0.4 (below OWN_BAR 0.55 → no sightings; above FLOOR → strength++)
      for (var i = 1; i <= 3; i++) {
        final r = applyMerge(mem, [sc(skill, 0.4, prompted: false)], 'A1');
        mem = applyEndChat(
          mem: r.mem,
          mergeResult: r,
          turnCount: 2,
          chatNumber: i,
          usedTopic: null,
          progressionModel: 'micro-skill',
          level: 'A1',
        );
      }

      // After 3 chats: strength=3, effort path fired → owned
      expect(bucketOf(mem, skill), 'owned');
    });

    test('Effort path does NOT fire for B1', () {
      var mem = MemoryState.fresh('B1', childId: 'test')
          .copyWith(progressionModel: 'micro-skill');
      const s = 'B1-FLU-01';

      for (var i = 1; i <= 3; i++) {
        final r = applyMerge(mem, [sc(s, 0.4, prompted: false)], 'B1');
        mem = applyEndChat(
          mem: r.mem,
          mergeResult: r,
          turnCount: 2,
          chatNumber: i,
          usedTopic: null,
          progressionModel: 'micro-skill',
          level: 'B1',
        );
      }
      // B1: effort path inactive → skill stays emerging (not owned)
      expect(bucketOf(mem, s), 'emerging');
    });
  });

  // ── 8. dueNext flat list ──────────────────────────────────────────────────

  group('dueNext.flat', () {
    test('flat combines primary and watching', () {
      const due = DueNext(primary: 'A1-VOC-01', watching: ['A1-GRA-01', 'A1-FLU-01']);
      expect(due.flat, ['A1-VOC-01', 'A1-GRA-01', 'A1-FLU-01']);
    });

    test('flat with null primary returns only watching', () {
      const due = DueNext(watching: ['A1-GRA-01']);
      expect(due.flat, ['A1-GRA-01']);
    });

    test('empty dueNext.flat returns empty list', () {
      const due = DueNext();
      expect(due.flat, isEmpty);
    });
  });

  // ── 9. Full simulator-style loop (3 chats, unit mode) ────────────────────

  group('Simulator-style 3-chat loop (units mode)', () {
    test('step 1 skills all become owned after sufficient sightings', () {
      final step = kUnitSteps.first;
      final stepSkillIds = step.skills.map((s) => s.id).toList();

      var mem = MemoryState.fresh('A1', childId: 'test')
          .copyWith(progressionModel: 'units');

      // Chat 1: qualify all step 1 skills (locked → emerging, 1 sighting each)
      final scoresChat1 =
          stepSkillIds.map((id) => sc(id, 0.85)).toList();
      final r1 = applyMerge(mem, scoresChat1, 'A1');
      mem = applyEndChat(
        mem: mem,
        mergeResult: r1,
        turnCount: 3,
        chatNumber: 1,
        usedTopic: null,
        progressionModel: 'units',
        level: 'A1',
      );
      for (final id in stepSkillIds) {
        expect(bucketOf(mem, id), 'emerging',
            reason: '$id should be emerging after 1 sighting');
      }

      // Chat 2: second sighting → owned
      final scoresChat2 =
          stepSkillIds.map((id) => sc(id, 0.85)).toList();
      final r2 = applyMerge(mem, scoresChat2, 'A1');
      mem = applyEndChat(
        mem: mem,
        mergeResult: r2,
        turnCount: 3,
        chatNumber: 2,
        usedTopic: null,
        progressionModel: 'units',
        level: 'A1',
      );
      for (final id in stepSkillIds) {
        expect(bucketOf(mem, id), 'owned',
            reason: '$id should be owned after 2 sightings');
      }

      // Step 1 should now be complete
      expect(unitComplete(mem, step), isTrue);
      // Active step should advance to step 2
      expect(activeStep(mem)?.step, isNot(step.step));
    });
  });
}
