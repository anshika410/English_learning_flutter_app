import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ella_app/models/child_memory.dart';
import 'package:ella_app/models/garden.dart';
import 'package:ella_app/providers/chat_provider.dart';
import 'package:ella_app/providers/garden_provider.dart';
import 'package:ella_app/providers/onboarding_provider.dart';
import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/garden_screen.dart';
import 'package:ella_app/screens/child_view/widgets/home_scene_background.dart';
import 'package:ella_app/screens/child_view/widgets/placement_garden_scene_background.dart';
import 'package:ella_app/screens/child_view/widgets/spotlight_overlay.dart';
import 'package:ella_app/services/audio_service.dart';
import 'package:ella_app/services/ella_api_service.dart';
import 'package:ella_app/services/sounds.dart';
import 'package:ella_app/services/stt_tts_service.dart';

const String _testUserId = 'garden-test-user';
const String _testCompletedIntroPrefsKey =
    '$completedGardenIntroSeenPrefsKeyPrefix:$_testUserId';

class _FakeAudioService extends AudioService {
  final List<AudioClip> playedSfx = [];

  @override
  bool get musicEnabled => true;

  @override
  bool get sfxEnabled => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playSfx(AudioClip clip) async => playedSfx.add(clip);

  @override
  Future<void> playMusic(AudioClip clip) async {}

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> duckForSpeech() async {}

  @override
  Future<void> unduckAfterSpeech() async {}

  @override
  Future<void> setSfxEnabled(bool value) async {}

  @override
  Future<void> setMusicEnabled(bool value) async {}

  @override
  Future<void> dispose() async {}
}

class _ImmediateTtsService extends FlutterTtsService {
  bool _speaking = false;
  String? lastSpoken;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    lastSpoken = text;
    _speaking = true;
    _speaking = false;
  }

  @override
  Future<void> stop() async => _speaking = false;

  @override
  bool get isSpeaking => _speaking;
}

class _ControllableTtsService extends FlutterTtsService {
  bool _speaking = false;
  Completer<void>? _completer;
  bool _finishRequested = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) {
    if (_finishRequested) {
      _finishRequested = false;
      _speaking = false;
      return Future<void>.value();
    }
    _speaking = true;
    _completer = Completer<void>();
    return _completer!.future.whenComplete(() => _speaking = false);
  }

  void finish() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete();
    } else {
      _finishRequested = true;
    }
  }

  @override
  Future<void> stop() async {
    _speaking = false;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete();
    }
  }

  @override
  bool get isSpeaking => _speaking;
}

class _FakeChatNotifier extends ChatNotifier {
  final String level;
  _FakeChatNotifier(this.level);

  @override
  Future<ChatState> build() async => ChatState(
    memory: MemoryState(childId: 'test-child', level: level),
  );
}

class _SeededPostConversationRevealController
    extends PostConversationGardenRevealController {
  _SeededPostConversationRevealController(PostConversationGardenReveal value) {
    state = value;
  }
}

class _FakeOnboardingNotifier extends OnboardingNotifier {
  final String childName;

  _FakeOnboardingNotifier([this.childName = 'Narendra']);

  @override
  Future<OnboardingState> build() async =>
      OnboardingState(done: true, name: childName, age: 10);
}

Widget _harness(
  GardenData data, {
  bool firstTime = false,
  bool disableAnimations = true,
  FlutterTtsService? tts,
  _FakeAudioService? audio,
  StateProvider<GardenData>? gardenDataProvider,
  String childName = 'Narendra',
  bool previousGardenFails = false,
  Future<GardenData> Function(String level)? previousGardenLoader,
  Future<GardenData> Function()? gardenLoader,
  PostConversationGardenReveal? postConversationReveal,
  Size mediaSize = const Size(430, 932),
  TextScaler textScaler = TextScaler.noScaling,
  List<Override> extraOverrides = const [],
}) {
  final sourceProvider =
      gardenDataProvider ?? StateProvider<GardenData>((ref) => data);
  final overrides = <Override>[
    audioProvider.overrideWithValue(audio ?? _FakeAudioService()),
    ttsProvider.overrideWithValue(tts ?? _ImmediateTtsService()),
    chatProvider.overrideWith(() => _FakeChatNotifier(data.level)),
    onboardingProvider.overrideWith(() => _FakeOnboardingNotifier(childName)),
    previousGardenProvider.overrideWith((ref, level) async {
      if (previousGardenLoader != null) {
        return previousGardenLoader(level);
      }
      if (previousGardenFails) {
        throw const EllaApiException('previous_garden_unavailable');
      }
      return _apiPreviousGarden(level);
    }),
    if (postConversationReveal != null)
      postConversationGardenRevealProvider.overrideWith(
        (ref) =>
            _SeededPostConversationRevealController(postConversationReveal),
      ),
    ...extraOverrides,
    gardenProvider.overrideWith(
      (ref) async =>
          gardenLoader == null ? ref.watch(sourceProvider) : gardenLoader(),
    ),
  ];

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: mediaSize,
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: GardenScreen(firstTime: firstTime),
      ),
    ),
  );
}

/// API-shaped previous garden — mirrors GET /users/me/garden?level=<code>.
/// Skill statuses/sightings come straight from the payload; sightings ≥ 3
/// renders as a bloomed plant.
GardenData _apiPreviousGarden(String level) => GardenData.fromJson({
  'level': level,
  'recommended_topic': 'Old favourites',
  'units': [
    {
      'unit': 1,
      'name': 'Describing the world',
      'focus': 'Moving from naming things to describing them.',
      'skills': [
        {
          'id': 'U1-VOC-01',
          'strand': 'VOC',
          'text': 'I can describe what people look like and how they feel.',
          'status': 'owned',
          'sightings': 3,
          'evidence': [
            {
              'evidence': 'My friend is tall and happy.',
              'confidence': 0.95,
              'prompted': true,
              'topic': 'My friends',
              'created_at': '2026-07-10T09:42:10+00:00',
            },
          ],
        },
        {
          'id': 'U1-GRA-01',
          'strand': 'GRA',
          'text': 'I can use the present continuous.',
          'status': 'owned',
          'sightings': 3,
          'evidence': const [],
        },
      ],
    },
  ],
});

GardenData _gardenData({
  required String level,
  String theme = '',
  List<GardenStep>? steps,
}) => GardenData(
  level: level,
  levelLabel: '',
  theme: theme,
  activeStepIndex: 1,
  recommendedTopic: '',
  steps: steps ?? [_step(level: level, step: 1, name: 'First Unit', count: 3)],
);

GardenStep _step({
  required String level,
  required int step,
  required String name,
  String displayName = '',
  String displayDescription = '',
  String icon = '',
  required int count,
  int sightings = 0,
}) => GardenStep(
  step: step,
  name: name,
  focus: '',
  displayName: displayName,
  displayDescription: displayDescription,
  icon: icon,
  isCompleted: false,
  skills: [
    for (var i = 0; i < count; i++)
      GardenSkill(
        id: '$level-U$step-S$i',
        strand: switch (i % 3) {
          0 => Strand.voc,
          1 => Strand.gra,
          _ => Strand.flu,
        },
        text: 'Skill $i',
        status: SkillStatus.locked,
        sightings: sightings,
        evidence: const [],
      ),
  ],
);

GardenSkill _skill({
  required String id,
  Strand strand = Strand.voc,
  String text = 'Describe people and how they feel',
  String displayText = '',
  int sightings = 0,
  SkillStatus? status,
  List<GardenEvidence> evidence = const [],
}) => GardenSkill(
  id: id,
  strand: strand,
  text: text,
  displayText: displayText,
  status:
      status ??
      (sightings >= 3
          ? SkillStatus.owned
          : sightings >= 1
          ? SkillStatus.emerging
          : SkillStatus.locked),
  sightings: sightings,
  evidence: evidence,
);

GardenStep _stepWithSkills({
  required int step,
  String name = 'First Unit',
  required List<GardenSkill> skills,
}) => GardenStep(
  step: step,
  name: name,
  focus: '',
  isCompleted: false,
  skills: skills,
);

GardenEvidence _evidence(String quote) => GardenEvidence(
  quote: quote,
  confidence: 0.86,
  prompted: false,
  topic: 'Family',
  createdAt: DateTime(2026, 7, 1),
);

PostConversationGardenReveal _postConversationResult({
  required int turnCount,
  required String skillId,
  int beforeSightings = 0,
  int afterSightings = 0,
  Set<String> beforeOwned = const {},
  Set<String> beforeEmerging = const {},
  Set<String> afterOwned = const {},
  Set<String> afterEmerging = const {},
  List<SkillScore> scores = const [],
  PostConversationGardenRevealStatus status =
      PostConversationGardenRevealStatus.resolved,
}) => PostConversationGardenReveal(
  status: status,
  chatNumber: 7,
  turnCount: turnCount,
  targetSkillIds: [skillId],
  beforeSightings: {skillId: beforeSightings},
  afterSightings: {skillId: afterSightings},
  beforeOwned: beforeOwned,
  beforeEmerging: beforeEmerging,
  afterOwned: afterOwned,
  afterEmerging: afterEmerging,
  sessionScores: scores,
);

GardenGrowthRevealItem _revealItem({
  required GardenStep step,
  required GardenSkill skill,
  required GardenGrowthStage from,
  required GardenGrowthStage to,
  int skillIndex = 0,
}) => GardenGrowthRevealItem(
  step: step,
  skill: skill,
  stepIndex: 0,
  skillIndex: skillIndex,
  fromStage: from,
  toStage: to,
  evidence: skill.evidence.isEmpty ? null : skill.evidence.first,
);

Future<void> _pumpGarden(
  WidgetTester tester,
  GardenData data, {
  bool previousGardenFails = false,
}) async {
  await tester.pumpWidget(
    _harness(data, previousGardenFails: previousGardenFails),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

Future<void> _pumpUntilSpeaking(
  WidgetTester tester,
  _ControllableTtsService tts,
) async {
  for (var i = 0; i < 8; i++) {
    if (tts.isSpeaking) return;
    await tester.pump();
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 12; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpUntilRevealCard(WidgetTester tester) => _pumpUntilFound(
  tester,
  find.byKey(const ValueKey('garden-growth-reveal-card')),
);

Future<void> _pumpUntilSfx(WidgetTester tester, _FakeAudioService audio) async {
  for (var i = 0; i < 40; i++) {
    if (audio.playedSfx.isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntilPrefsContain(
  WidgetTester tester,
  String key,
  String value,
) async {
  for (var i = 0; i < 12; i++) {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getStringList(key) ?? const <String>[]).contains(value)) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'ella_api_user_id': _testUserId});
  });

  testWidgets('initial loading keeps the placement-garden scenery', (
    tester,
  ) async {
    final pending = Completer<GardenData>();
    await tester.pumpWidget(
      _harness(
        _gardenData(level: 'A1'),
        gardenLoader: () => pending.future,
        mediaSize: const Size(390, 844),
      ),
    );
    await tester.pump();

    expect(find.text('Preparing your garden...'), findsOneWidget);
    expect(find.byType(PlacementGardenBackdrop), findsOneWidget);
    expect(
      find.byKey(const ValueKey('placement-garden-status-background')),
      findsOneWidget,
    );
    expect(find.byType(HomeSceneBackground), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(_gardenData(level: 'A1'));
  });

  testWidgets('initial errors keep the placement-garden scenery', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _gardenData(level: 'A1'),
        gardenLoader: () =>
            Future.error(const EllaApiException('garden_unavailable')),
        mediaSize: const Size(320, 700),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No Internet Connection'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.byType(PlacementGardenBackdrop), findsOneWidget);
    expect(find.byType(HomeSceneBackground), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('known levels render their Figma garden labels', (tester) async {
    final cases = {
      'A0': 'Dawn Glade',
      'A1': 'Morning Meadow',
      'A2': 'Midday Grove',
      'B1': 'Golden Orchard',
      'B2': 'Twilight Valley',
      'C1': 'Starlight Summit',
    };

    for (final entry in cases.entries) {
      await _pumpGarden(
        tester,
        _gardenData(level: entry.key, theme: 'Backend Legacy Theme'),
      );

      expect(find.text(entry.value), findsOneWidget);
      expect(
        find.byKey(ValueKey('garden-backdrop-${entry.key}')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('growth reveal diff uses garden order and skips missing snapshot', () {
    final before = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(
          step: 1,
          skills: [
            _skill(id: 's0', sightings: 0),
            _skill(id: 's1', sightings: 1),
          ],
        ),
        _stepWithSkills(step: 2, skills: [_skill(id: 's2', sightings: 2)]),
      ],
    );
    final after = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(
          step: 1,
          skills: [
            _skill(
              id: 's0',
              sightings: 1,
              evidence: [_evidence('I used a new word.')],
            ),
            _skill(
              id: 's1',
              sightings: 2,
              evidence: [_evidence('I added more detail.')],
            ),
          ],
        ),
        _stepWithSkills(
          step: 2,
          skills: [
            _skill(
              id: 's2',
              sightings: 3,
              evidence: [_evidence('Now it feels easy.')],
            ),
          ],
        ),
      ],
    );

    expect(buildGardenGrowthRevealItems(before: null, after: after), isEmpty);

    final items = buildGardenGrowthRevealItems(before: before, after: after);
    expect(items.map((item) => item.skillId), ['s0', 's1', 's2']);
    expect(items.map((item) => item.fromStage), [
      GardenGrowthStage.seed,
      GardenGrowthStage.sprout,
      GardenGrowthStage.budding,
    ]);
    expect(items.map((item) => item.toStage), [
      GardenGrowthStage.sprout,
      GardenGrowthStage.budding,
      GardenGrowthStage.bloomed,
    ]);
  });

  test(
    'post-conversation snapshots detect growth without a mounted garden',
    () {
      final skill = _skill(id: 'target', sightings: 1);
      final after = _gardenData(
        level: 'A1',
        steps: [
          _stepWithSkills(step: 1, skills: [skill]),
        ],
      );
      final result = _postConversationResult(
        turnCount: 3,
        skillId: skill.id,
        beforeSightings: 0,
        afterSightings: 1,
        afterEmerging: {skill.id},
        scores: [
          SkillScore(
            id: skill.id,
            confidence: 0.91,
            prompted: false,
            evidence: 'I described my family.',
          ),
        ],
      );

      final items = buildPostConversationGrowthRevealItems(
        after: after,
        result: result,
      );

      expect(items, hasLength(1));
      expect(items.single.fromStage, GardenGrowthStage.seed);
      expect(items.single.toStage, GardenGrowthStage.sprout);
      expect(items.single.wateringOnly, isFalse);
      expect(items.single.evidence?.quote, 'I described my family.');
    },
  );

  test(
    'no-growth reveal uses quick hello below 3 and strongest session line at 3',
    () {
      final target = _skill(id: 'target');
      final after = _gardenData(
        level: 'A1',
        steps: [
          _stepWithSkills(step: 1, skills: [target]),
        ],
      );
      final targetScore = SkillScore(
        id: target.id,
        confidence: 0.72,
        prompted: false,
        evidence: 'This line matched the target skill.',
      );
      final strongestScore = SkillScore(
        id: 'another-skill',
        confidence: 0.94,
        prompted: false,
        evidence: 'This was the strongest line in the conversation.',
      );

      final quick = buildGardenWateringRevealItem(
        after: after,
        aimedAt: [target.id],
        turnCount: 2,
        sessionScores: [targetScore, strongestScore],
      );
      final watering = buildGardenWateringRevealItem(
        after: after,
        aimedAt: [target.id],
        turnCount: 3,
        sessionScores: [targetScore, strongestScore],
      );

      expect(quick?.quickHello, isTrue);
      expect(watering?.quickHello, isFalse);
      expect(watering?.wateringOnly, isTrue);
      expect(watering?.skillId, target.id);
      expect(
        watering?.evidence?.quote,
        'This was the strongest line in the conversation.',
      );
    },
  );

  test('watering falls back to an active non-owned skill', () {
    final owned = _skill(id: 'owned', sightings: 3, status: SkillStatus.owned);
    final fallback = _skill(id: 'fallback', sightings: 1);
    final after = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(step: 1, skills: [owned, fallback]),
      ],
    );

    final watering = buildGardenWateringRevealItem(
      after: after,
      aimedAt: const ['missing-target'],
      turnCount: 4,
    );

    expect(watering?.skillId, fallback.id);
  });

  testWidgets('pending result waters and alternates sides until it resolves', (
    tester,
  ) async {
    const skillId = 'target';
    final skill = _skill(id: skillId);
    final data = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(step: 1, skills: [skill]),
      ],
    );
    final analyzing = _postConversationResult(
      turnCount: 3,
      skillId: skillId,
      status: PostConversationGardenRevealStatus.analyzing,
    );
    await tester.pumpWidget(
      _harness(
        data,
        disableAnimations: false,
        postConversationReveal: analyzing,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('garden-preparing-overlay')),
      findsNothing,
    );
    expect(find.text('Preparing your garden…'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'garden-watering-right-0-',
            ),
      ),
      findsOneWidget,
    );
    expect(find.text('Just a little more watering…'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('garden-scoring-wait-card-opacity')),
          )
          .opacity,
      0,
    );

    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'garden-watering-left-1-',
            ),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('garden-scoring-wait-card-opacity')),
          )
          .opacity,
      1,
    );
    expect(
      find.byKey(const ValueKey('garden-scoring-wait-zoe')),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GardenScreen)),
    );
    final before = MemoryState(childId: 'test', level: 'A1');
    container
        .read(postConversationGardenRevealProvider.notifier)
        .resolve(
          chatNumber: 7,
          turnCount: 3,
          targetSkillIds: const [skillId],
          before: before,
          after: before,
          sessionScores: const [],
        );
    container.invalidate(gardenProvider);
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('garden-growth-reveal-card-opacity')),
          )
          .opacity,
      0,
    );
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('You watered your garden today'), findsOneWidget);
    expect(find.text('A line to remember'), findsNothing);
  });

  testWidgets('pending quick hello skips speculative watering', (tester) async {
    const skillId = 'target';
    final skill = _skill(id: skillId);
    final data = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(step: 1, skills: [skill]),
      ],
    );
    final analyzing = _postConversationResult(
      turnCount: 2,
      skillId: skillId,
      status: PostConversationGardenRevealStatus.analyzing,
    );

    await tester.pumpWidget(_harness(data, postConversationReveal: analyzing));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'garden-watering-',
            ),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('garden-scoring-wait-card-opacity')),
          )
          .opacity,
      0,
    );
  });

  testWidgets('resolved growth on another plot gets a final focused pour', (
    tester,
  ) async {
    const targetId = 'target-one';
    const growthId = 'growth-two';
    final beforeGarden = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(step: 1, skills: [_skill(id: targetId)]),
        _stepWithSkills(step: 2, skills: [_skill(id: growthId)]),
      ],
    );
    final afterGarden = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(step: 1, skills: [_skill(id: targetId)]),
        _stepWithSkills(step: 2, skills: [_skill(id: growthId, sightings: 1)]),
      ],
    );
    final source = StateProvider<GardenData>((ref) => beforeGarden);
    final analyzing = _postConversationResult(
      turnCount: 3,
      skillId: targetId,
      status: PostConversationGardenRevealStatus.analyzing,
    );

    await tester.pumpWidget(
      _harness(
        beforeGarden,
        disableAnimations: false,
        gardenDataProvider: source,
        postConversationReveal: analyzing,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GardenScreen)),
    );
    final beforeMemory = MemoryState(childId: 'test', level: 'A1');
    container.read(source.notifier).state = afterGarden;
    container
        .read(postConversationGardenRevealProvider.notifier)
        .resolve(
          chatNumber: 7,
          turnCount: 3,
          targetSkillIds: const [targetId, growthId],
          before: beforeMemory,
          after: beforeMemory.copyWith(
            emerging: const [growthId],
            sightings: const {growthId: 1},
          ),
          sessionScores: const [],
        );
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'garden-watering-',
            ) &&
            (widget.key! as ValueKey<String>).value.contains(growthId),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('garden-scoring-wait-card-opacity')),
          )
          .opacity,
      0,
    );
  });

  testWidgets('resolved result is consumed on the garden first load', (
    tester,
  ) async {
    const skillId = 'target';
    final skill = _skill(id: skillId);
    final data = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(step: 1, skills: [skill]),
      ],
    );
    final resolved = _postConversationResult(turnCount: 1, skillId: skillId);

    await tester.pumpWidget(_harness(data, postConversationReveal: resolved));
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('garden-quick-hello-card')),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GardenScreen)),
    );
    expect(container.read(postConversationGardenRevealProvider), isNull);
    expect(
      find.byKey(const ValueKey('garden-preparing-overlay')),
      findsNothing,
    );
    expect(find.text('That was a quick hello 👋'), findsOneWidget);
    expect(find.text("We can talk more whenever you're ready"), findsOneWidget);
    final quickCard = find.byKey(const ValueKey('garden-quick-hello-card'));
    expect(tester.getSize(quickCard).width, lessThanOrEqualTo(330));
    expect(
      tester.getCenter(quickCard).dx,
      closeTo(tester.getCenter(find.byType(GardenScreen)).dx, 0.1),
    );
    final quickTitle = tester.widget<Text>(
      find.byKey(const ValueKey('garden-quick-hello-title')),
    );
    expect(quickTitle.style?.fontSize, 16);
  });

  testWidgets('resolved growth takes precedence over watering on first load', (
    tester,
  ) async {
    const skillId = 'target';
    final skill = _skill(id: skillId, sightings: 1);
    final data = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(step: 1, skills: [skill]),
      ],
    );
    final resolved = _postConversationResult(
      turnCount: 3,
      skillId: skillId,
      beforeSightings: 0,
      afterSightings: 1,
      afterEmerging: const {skillId},
    );

    await tester.pumpWidget(_harness(data, postConversationReveal: resolved));
    await tester.pump();
    await _pumpUntilRevealCard(tester);

    expect(find.text('A new skill is sprouting'), findsOneWidget);
    expect(find.text('You watered your garden today'), findsNothing);
    expect(
      find.byKey(const ValueKey('garden-preparing-overlay')),
      findsNothing,
    );
  });

  testWidgets('watering reveal spotlights and waters before showing its card', (
    tester,
  ) async {
    const skillId = 'target';
    final skill = _skill(id: skillId);
    final data = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(step: 1, skills: [skill]),
      ],
    );
    final resolved = _postConversationResult(turnCount: 3, skillId: skillId);

    await tester.pumpWidget(
      _harness(
        data,
        disableAnimations: false,
        postConversationReveal: resolved,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('garden-growth-spotlight-layer')),
      findsOneWidget,
    );
    final spotlight = tester.widget<SpotlightOverlay>(
      find.byType(SpotlightOverlay),
    );
    expect(spotlight.radius, 0.9);
    final spotlightLayer = find.byKey(
      const ValueKey('garden-growth-spotlight-layer'),
    );
    expect(tester.widget<AnimatedOpacity>(spotlightLayer).opacity, 1);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            ((widget.key! as ValueKey<String>).value.startsWith(
                  'garden-watering-right-0-target:',
                ) ||
                (widget.key! as ValueKey<String>).value.startsWith(
                  'garden-watering-left-0-target:',
                )),
      ),
      findsOneWidget,
    );
    final canArt = find.byKey(const ValueKey('garden-watering-can-art'));
    expect(tester.getSize(canArt), const Size(64, 56));
    final cardOpacity = find.byKey(
      const ValueKey('garden-growth-reveal-card-opacity'),
    );
    expect(tester.widget<AnimatedOpacity>(cardOpacity).opacity, 0);

    // The can reaches its one-second pour window at 600ms. Droplets are still
    // active near the end of that window, and Zoe must wait for the exit.
    await tester.pump(const Duration(milliseconds: 650));
    final canTransform = tester.widget<Transform>(
      find.byKey(const ValueKey('garden-watering-can-transform')),
    );
    expect(canTransform.transform.storage[1], lessThan(0));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'garden-water-drop-',
            ),
      ),
      findsWidgets,
    );
    expect(tester.widget<AnimatedOpacity>(cardOpacity).opacity, 0);

    await tester.pump(const Duration(milliseconds: 700));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'garden-water-drop-',
            ),
      ),
      findsWidgets,
    );
    expect(tester.widget<AnimatedOpacity>(cardOpacity).opacity, 0);

    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('You watered your garden today'), findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(cardOpacity).opacity, 1);
    expect(tester.widget<AnimatedOpacity>(spotlightLayer).opacity, 1);
  });

  testWidgets(
    'watering card uses garden-wide copy and strongest session line',
    (tester) async {
      const skillId = 'target';
      final skill = _skill(id: skillId);
      final data = _gardenData(
        level: 'A1',
        steps: [
          _stepWithSkills(step: 1, skills: [skill]),
        ],
      );
      final resolved = _postConversationResult(
        turnCount: 3,
        skillId: skillId,
        scores: const [
          SkillScore(
            id: skillId,
            confidence: 0.71,
            prompted: false,
            evidence: 'I described my family.',
          ),
          SkillScore(
            id: 'different-skill',
            confidence: 0.93,
            prompted: false,
            evidence: 'I told a detailed story about our trip.',
          ),
        ],
      );

      await tester.pumpWidget(
        _harness(
          data,
          disableAnimations: true,
          postConversationReveal: resolved,
        ),
      );
      await tester.pump();
      await _pumpUntilRevealCard(tester);

      expect(find.text('You watered your garden today'), findsOneWidget);
      expect(
        find.text('Every conversation gives your English a little more life.'),
        findsOneWidget,
      );
      expect(find.text('A line to remember'), findsOneWidget);
      expect(
        find.text('I told a detailed story about our trip.'),
        findsOneWidget,
      );
      expect(
        find.text('This had the highest confidence in this conversation.'),
        findsNothing,
      );
      final wateringCard = find.byKey(
        const ValueKey('garden-watering-reveal-card'),
      );
      expect(
        find.descendant(
          of: wateringCard,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(find.text(skill.displayText), findsNothing);
      expect(
        find.textContaining('You practiced this skill with Zoe'),
        findsNothing,
      );
    },
  );

  testWidgets('watering presentation contains long content on short screens', (
    tester,
  ) async {
    const skillId = 'target';
    final skill = _skill(id: skillId);
    final data = _gardenData(
      level: 'A1',
      steps: [
        _stepWithSkills(step: 1, skills: [skill]),
      ],
    );
    final resolved = _postConversationResult(
      turnCount: 3,
      skillId: skillId,
      scores: const [
        SkillScore(
          id: skillId,
          confidence: 0.94,
          prompted: false,
          evidence:
              'I carefully described the whole journey and explained why it '
              'was memorable for everyone in my family.',
        ),
      ],
    );

    await tester.pumpWidget(
      _harness(
        data,
        postConversationReveal: resolved,
        mediaSize: const Size(360, 640),
        textScaler: TextScaler.linear(1.3),
      ),
    );
    await tester.pump();
    await _pumpUntilRevealCard(tester);

    expect(
      find.byKey(const ValueKey('garden-watering-reveal-presentation-scroll')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('garden-watering-reveal-note')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('growth reveal renders seed sprout budding and bloom copy', (
    tester,
  ) async {
    final cases = [
      (
        from: GardenGrowthStage.seed,
        to: GardenGrowthStage.sprout,
        sightings: 1,
        title: 'A new skill is sprouting',
      ),
      (
        from: GardenGrowthStage.sprout,
        to: GardenGrowthStage.budding,
        sightings: 2,
        title: 'This skill just grew stronger',
      ),
      (
        from: GardenGrowthStage.budding,
        to: GardenGrowthStage.bloomed,
        sightings: 3,
        title: 'This skill is in full bloom!',
      ),
    ];

    for (final growthCase in cases) {
      final skill = _skill(
        id: 'growth-${growthCase.to.key}',
        sightings: growthCase.sightings,
        evidence: [_evidence('I am very happy talking to my family.')],
      );
      final step = _stepWithSkills(step: 1, skills: [skill]);
      await tester.pumpWidget(
        _harness(
          _gardenData(level: 'A1', steps: [step]),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GardenScreen)),
      );
      container.read(gardenGrowthRevealProvider.notifier).setQueue([
        _revealItem(
          step: step,
          skill: skill,
          from: growthCase.from,
          to: growthCase.to,
        ),
      ]);
      await tester.pump();
      await _pumpUntilRevealCard(tester);

      expect(find.text(growthCase.title), findsOneWidget);
      expect(find.text(growthCase.from.label), findsOneWidget);
      expect(find.text(growthCase.to.label), findsOneWidget);
      expect(find.text('What You Said'), findsOneWidget);
      expect(
        find.text('I am very happy talking to my family.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('growth reveal uses refreshed skill copy without TTS', (
    tester,
  ) async {
    final tts = _ImmediateTtsService();
    final skill = _skill(
      id: 'display-copy-growth',
      text: 'Canonical framework skill statement',
      displayText: 'Use words like yesterday, last week',
      sightings: 1,
      evidence: [_evidence('Yesterday I played cricket.')],
    );
    final step = _stepWithSkills(step: 2, skills: [skill]);

    await tester.pumpWidget(
      _harness(
        _gardenData(level: 'A1', steps: [step]),
        disableAnimations: true,
        tts: tts,
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GardenScreen)),
    );
    container.read(gardenGrowthRevealProvider.notifier).setQueue([
      _revealItem(
        step: step,
        skill: skill,
        from: GardenGrowthStage.seed,
        to: GardenGrowthStage.sprout,
      ),
    ]);
    await tester.pump();
    await _pumpUntilRevealCard(tester);

    expect(find.text('Use words like yesterday, last week'), findsOneWidget);
    expect(find.text('Canonical framework skill statement'), findsNothing);
    expect(tts.lastSpoken, isNull);

    final cardTop = tester.getTopLeft(
      find.byKey(const ValueKey('garden-growth-reveal-card')),
    );
    final zoeTop = tester.getTopLeft(
      find.byKey(const ValueKey('garden-growth-reveal-zoe')),
    );
    final plantCenter = tester.getCenter(
      find.byKey(const ValueKey('garden-plant-slot-display-copy-growth')),
    );
    // The spotlit plant is scrolled near the top of the viewport before the
    // card shows, so the card now places below the plant by default.
    expect(cardTop.dy, greaterThan(plantCenter.dy));
    expect(zoeTop.dx, lessThan(cardTop.dx + 8));
    expect(zoeTop.dy, lessThan(cardTop.dy));
  });

  testWidgets('multiple growth reveal items advance with See Next Plant', (
    tester,
  ) async {
    final skillOne = _skill(
      id: 'growth-one',
      text: 'Use a new word',
      sightings: 1,
      evidence: [_evidence('I used a new word.')],
    );
    final skillTwo = _skill(
      id: 'growth-two',
      text: 'Connect two ideas',
      sightings: 2,
      evidence: [_evidence('I connected two ideas.')],
    );
    final step = _stepWithSkills(step: 1, skills: [skillOne, skillTwo]);

    await tester.pumpWidget(
      _harness(
        _gardenData(level: 'A1', steps: [step]),
        disableAnimations: true,
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GardenScreen)),
    );
    container.read(gardenGrowthRevealProvider.notifier).setQueue([
      _revealItem(
        step: step,
        skill: skillOne,
        from: GardenGrowthStage.seed,
        to: GardenGrowthStage.sprout,
      ),
      _revealItem(
        step: step,
        skill: skillTwo,
        from: GardenGrowthStage.sprout,
        to: GardenGrowthStage.budding,
        skillIndex: 1,
      ),
    ]);
    await tester.pump();
    await _pumpUntilRevealCard(tester);

    expect(find.text('Use a new word'), findsOneWidget);
    expect(find.text('See Next Plant'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-talk-bar-layer')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('garden-growth-reveal-cta')));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Connect two ideas'));

    expect(find.text('Connect two ideas'), findsOneWidget);
    expect(find.text('Explore Garden'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('garden-growth-reveal-cta')));
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('garden-talk-bar-layer')),
    );

    expect(
      find.byKey(const ValueKey('garden-growth-reveal-card')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('garden-talk-bar-layer')), findsOneWidget);
  });

  testWidgets(
    'unknown future levels use backend label with A2 visual fallback',
    (tester) async {
      await _pumpGarden(
        tester,
        _gardenData(level: 'B3', theme: 'Future Garden'),
      );

      expect(find.text('Future Garden'), findsOneWidget);
      expect(find.byKey(const ValueKey('garden-backdrop-A2')), findsOneWidget);
    },
  );

  testWidgets('garden title uses first name only', (tester) async {
    await tester.pumpWidget(
      _harness(_gardenData(level: 'B1'), childName: 'Narendra Singh'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text("Narendra's Garden"), findsOneWidget);
    expect(find.text("Narendra Singh's Garden"), findsNothing);
  });

  testWidgets('level selector is 48px tall and centered', (tester) async {
    await _pumpGarden(tester, _gardenData(level: 'C1'));

    final selector = find.byKey(const ValueKey('garden-level-selector'));
    expect(selector, findsOneWidget);
    expect(tester.getSize(selector).height, 48);
    final screenCenter = tester.getSize(find.byType(GardenScreen)).width / 2;
    expect(tester.getCenter(selector).dx, closeTo(screenCenter, 0.5));
    expect(find.text('Starlight Summit'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('garden-level-selector-icon'))),
      const Size(24, 24),
    );
  });

  testWidgets('C1 renders Figma stars and B2 renders none', (tester) async {
    await _pumpGarden(tester, _gardenData(level: 'C1'));

    for (var i = 0; i < 9; i++) {
      expect(find.byKey(ValueKey('garden-star-C1-$i')), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpGarden(tester, _gardenData(level: 'B2'));

    for (var i = 0; i < 9; i++) {
      expect(find.byKey(ValueKey('garden-star-B2-$i')), findsNothing);
    }
  });

  testWidgets(
    'clouds are smaller higher and drift with reduced-motion support',
    (tester) async {
      await tester.pumpWidget(
        _harness(_gardenData(level: 'A0'), disableAnimations: false),
      );
      await tester.pump();

      final leftCloud = find.byKey(const ValueKey('garden-cloud-left'));
      final rightCloud = find.byKey(const ValueKey('garden-cloud-right'));
      expect(leftCloud, findsOneWidget);
      expect(rightCloud, findsOneWidget);
      expect(tester.getSize(leftCloud).width, 60);
      expect(tester.getTopLeft(leftCloud).dy, closeTo(104, 0.5));

      final leftStart = tester.getTopLeft(leftCloud).dx;
      final rightStart = tester.getTopLeft(rightCloud).dx;
      await tester.pump(const Duration(seconds: 2));

      expect(tester.getTopLeft(leftCloud).dx, greaterThan(leftStart));
      expect(tester.getTopLeft(rightCloud).dx, lessThan(rightStart));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_harness(_gardenData(level: 'A0')));
      await tester.pump();

      final stillLeftStart = tester.getTopLeft(leftCloud).dx;
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getTopLeft(leftCloud).dx, closeTo(stillLeftStart, 0.001));
    },
  );

  testWidgets('unit signposts render without circular badges', (tester) async {
    await _pumpGarden(tester, _gardenData(level: 'A0'));

    expect(find.text('First Unit'), findsOneWidget);
    expect(find.byIcon(Icons.card_giftcard_rounded), findsNothing);
  });

  testWidgets('unit signposts render refreshed display names', (tester) async {
    await _pumpGarden(
      tester,
      _gardenData(
        level: 'A0',
        steps: [
          _step(
            level: 'A0',
            step: 3,
            name: "I like and I don't like",
            displayName: 'Likes and dislikes',
            count: 3,
          ),
        ],
      ),
    );

    expect(find.text('Likes and dislikes'), findsOneWidget);
    expect(find.text("I like and I don't like"), findsNothing);
  });

  testWidgets('unit boulders use fixed geometry and 24px centered icons', (
    tester,
  ) async {
    await _pumpGarden(
      tester,
      _gardenData(
        level: 'A0',
        steps: [
          _step(
            level: 'A0',
            step: 1,
            name: 'Hi',
            icon: 'assets/unit-icons/a1-a2/u1-globe.svg',
            count: 3,
          ),
          _step(
            level: 'A0',
            step: 2,
            name: 'Finding Better Words',
            icon: 'assets/unit-icons/a1-a2/u1-globe.svg',
            count: 3,
          ),
        ],
      ),
    );

    final boulders = find.byWidgetPredicate((widget) {
      if (widget.key is! ValueKey<String>) return false;
      final value = (widget.key! as ValueKey<String>).value;
      return value == 'garden-unit-sign-1' || value == 'garden-unit-sign-2';
    });
    final content = find.byKey(const ValueKey('garden-unit-sign-content'));
    final icons = find.byKey(const ValueKey('garden-unit-sign-icon'));
    final labels = find.byKey(const ValueKey('garden-unit-sign-label'));
    expect(boulders, findsNWidgets(2));
    expect(content, findsNWidgets(2));
    expect(icons, findsNWidgets(2));
    expect(labels, findsNWidgets(2));
    expect(tester.getSize(boulders.at(0)).width, 164);
    expect(tester.getSize(boulders.at(0)).height, closeTo(164 / 1.48, 0.01));
    expect(tester.getSize(icons.at(0)), const Size(24, 24));
    expect(tester.getSize(icons.at(1)), const Size(24, 24));
    expect(
      tester.getSize(content.at(0)).height,
      lessThan(tester.getSize(content.at(1)).height),
    );
    for (var i = 0; i < 2; i++) {
      expect(
        tester.getCenter(content.at(i)).dy,
        closeTo(tester.getCenter(boulders.at(i)).dy, 0.01),
      );
      final boulderRect = tester.getRect(boulders.at(i));
      final contentRect = tester.getRect(content.at(i));
      expect(boulderRect.contains(contentRect.topLeft), isTrue);
      expect(
        boulderRect.contains(contentRect.bottomRight - const Offset(0.1, 0.1)),
        isTrue,
      );
    }
  });

  testWidgets('garden sheet board grows and keeps content below it', (
    tester,
  ) async {
    await _pumpGarden(
      tester,
      _gardenData(
        level: 'A0',
        steps: [
          _step(
            level: 'A0',
            step: 1,
            name: 'Finding Better Words',
            displayDescription: 'Short unit description',
            count: 3,
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('garden-unit-sign-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final shortBoard = find.byKey(const ValueKey('garden-sheet-board'));
    final shortCard = find.byKey(const ValueKey('garden-sheet-card'));
    final shortDescription = find.text('Short unit description');
    expect(tester.getSize(shortBoard).width, greaterThan(268));
    expect(tester.getSize(shortBoard).height, 48);
    final shortContentGap =
        tester.getTopLeft(shortDescription).dy -
        tester.getTopLeft(shortCard).dy;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _harness(
        _gardenData(
          level: 'A0',
          steps: [
            _step(
              level: 'A0',
              step: 1,
              name: 'Saying what I can do',
              displayDescription: 'Tall unit description',
              count: 3,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(find.byKey(const ValueKey('garden-unit-sign-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final tallBoard = find.byKey(const ValueKey('garden-sheet-board'));
    final tallCard = find.byKey(const ValueKey('garden-sheet-card'));
    final tallDescription = find.text('Tall unit description');
    expect(tester.getSize(tallBoard).height, 64);
    expect(
      tester.getTopLeft(tallDescription).dy - tester.getTopLeft(tallCard).dy,
      greaterThan(shortContentGap),
    );
  });

  testWidgets(
    'unit sheet skill rows use title heading larger icons and semibold names',
    (tester) async {
      final step = GardenStep(
        step: 1,
        name: 'Finding Better Words',
        focus: '',
        displayDescription: 'Skill row polish check',
        isCompleted: false,
        skills: [
          _skill(id: 'voc-skill', strand: Strand.voc, text: 'Precise Word'),
          _skill(id: 'gra-skill', strand: Strand.gra, text: 'Grammar Shape'),
          _skill(id: 'flu-skill', strand: Strand.flu, text: 'Fluent Thread'),
        ],
      );
      await _pumpGarden(tester, _gardenData(level: 'A0', steps: [step]));

      await tester.tap(find.byKey(const ValueKey('garden-unit-sign-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('On Mastery, You Will Be Able To'), findsOneWidget);
      expect(find.text('ON MASTERY, YOU WILL BE ABLE TO'), findsNothing);
      expect(
        tester.getSize(
          find.byKey(const ValueKey('garden-unit-skill-icon-voc-skill')),
        ),
        const Size(48, 48),
      );
      final skillName = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('garden-unit-skill-row-voc-skill')),
          matching: find.text('Precise Word'),
        ),
      );
      expect(skillName.style?.fontWeight, FontWeight.w600);
      expect(find.text('Vocabulary'), findsOneWidget);
      expect(find.text('Grammar'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('garden-unit-show-more')));
      await tester.pump();

      expect(find.text('Fluency'), findsOneWidget);
    },
  );

  testWidgets('unit signboard is painted behind plot art in row stack', (
    tester,
  ) async {
    final data = _gardenData(
      level: 'A0',
      steps: [
        _step(level: 'A0', step: 1, name: 'Finding Better Words', count: 3),
      ],
    );
    await _pumpGarden(tester, data);

    final rowStack = tester.widgetList<Stack>(find.byType(Stack)).firstWhere((
      stack,
    ) {
      final childKeys = [
        for (final child in stack.children)
          if (child is Positioned) child.child.key,
      ];
      return childKeys.contains(const ValueKey('garden-unit-sign-1')) &&
          childKeys.contains(const ValueKey('garden-plot-1'));
    });
    final signIndex = rowStack.children.indexWhere(
      (child) =>
          child is Positioned &&
          child.child.key == const ValueKey('garden-unit-sign-1'),
    );
    final plotIndex = rowStack.children.indexWhere(
      (child) =>
          child is Positioned &&
          child.child.key == const ValueKey('garden-plot-1'),
    );

    expect(signIndex, lessThan(plotIndex));
  });

  testWidgets('B1 B2 and C1 render expanded fence counts', (tester) async {
    final cases = {'B1': 6, 'B2': 8, 'C1': 10};

    for (final entry in cases.entries) {
      await _pumpGarden(tester, _gardenData(level: entry.key));

      expect(
        find.byKey(ValueKey('garden-fence-run-${entry.key}-0-${entry.value}')),
        findsOneWidget,
      );
      for (var i = 0; i < entry.value; i++) {
        expect(
          find.byKey(ValueKey('garden-fence-${entry.key}-0-$i')),
          findsOneWidget,
        );
      }
      expect(
        tester.getSize(find.byKey(ValueKey('garden-fence-${entry.key}-0-0'))),
        const Size(57.6, 34.8),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('side props and Morning Meadow bird render larger', (
    tester,
  ) async {
    final cases = {
      'A0': (key: 'garden-side-prop-A0-grassTuft', size: const Size(112, 140)),
      'A1': (
        key: 'garden-side-prop-A1-wildflowers',
        size: const Size(156, 135),
      ),
      'B1': (key: 'garden-side-prop-B1-mushrooms', size: const Size(156, 120)),
      'C1': (key: 'garden-side-prop-C1-lantern', size: const Size(135, 165)),
    };

    for (final entry in cases.entries) {
      await _pumpGarden(tester, _gardenData(level: entry.key));

      final propSize = tester.getSize(find.byKey(ValueKey(entry.value.key)));
      expect(propSize.width, greaterThanOrEqualTo(entry.value.size.width));
      expect(propSize.height, greaterThanOrEqualTo(entry.value.size.height));
      if (entry.key == 'A1') {
        expect(
          tester.getSize(find.byKey(const ValueKey('garden-ambient-bird'))),
          const Size(76.8, 64.8),
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('plant stages are larger and centered on their tile bases', (
    tester,
  ) async {
    final skills = [
      _skill(id: 'sprout', sightings: 1),
      _skill(id: 'bud', sightings: 2),
      _skill(id: 'bloom', sightings: 3),
    ];
    await _pumpGarden(
      tester,
      _gardenData(
        level: 'A1',
        steps: [_stepWithSkills(step: 1, skills: skills)],
      ),
    );

    final expectedHeights = {'sprout': 82.5, 'bud': 116.6, 'bloom': 150.7};
    final expectedVerticalNudges = {'sprout': -12.0, 'bud': 0.0, 'bloom': 12.0};
    for (final entry in expectedHeights.entries) {
      final tile = find.byKey(ValueKey('garden-skill-tile-${entry.key}'));
      final plantSlot = find.byKey(ValueKey('garden-plant-slot-${entry.key}'));
      final plantArt = find.byKey(ValueKey('garden-plant-art-${entry.key}'));

      expect(tester.getSize(plantArt).height, entry.value);
      expect(
        tester.getCenter(plantSlot).dx,
        closeTo(tester.getCenter(tile).dx, 0.5),
      );
      expect(
        tester.getTopLeft(plantSlot).dy +
            (tester.getBottomLeft(plantSlot).dy -
                    tester.getTopLeft(plantSlot).dy) *
                0.92,
        closeTo(() {
          final renderedTileHeight =
              tester.getBottomLeft(tile).dy - tester.getTopLeft(tile).dy;
          final rowScale = renderedTileHeight / 80;
          return tester.getTopLeft(tile).dy +
              renderedTileHeight * 0.50 +
              expectedVerticalNudges[entry.key]! * rowScale;
        }(), 0.5),
      );
    }
  });

  testWidgets('renders dynamic units and 3/4/5 skill tile layouts', (
    tester,
  ) async {
    final data = _gardenData(
      level: 'A2',
      steps: [
        _step(level: 'A2', step: 1, name: 'Finding Better Words', count: 3),
        _step(
          level: 'A2',
          step: 2,
          name: 'Talking About The Past With More Precision',
          count: 4,
        ),
        _step(
          level: 'A2',
          step: 3,
          name: 'A Very Long Unit Name That Should Wrap Gracefully',
          count: 5,
        ),
      ],
    );

    await _pumpGarden(tester, data);

    expect(find.text('Midday Grove'), findsOneWidget);
    expect(find.text('Finding Better Words'), findsOneWidget);
    expect(
      find.text('Talking About The Past With More Precision'),
      findsOneWidget,
    );
    expect(
      find.text('A Very Long Unit Name That Should Wrap Gracefully'),
      findsOneWidget,
    );

    for (final step in data.steps) {
      expect(find.byKey(ValueKey('garden-unit-${step.step}')), findsOneWidget);
      for (final skill in step.skills) {
        expect(
          find.byKey(ValueKey('garden-skill-tile-${skill.id}')),
          findsOneWidget,
        );
      }
    }
  });

  testWidgets('first-time garden waits for Zoe before Explore Garden appears', (
    tester,
  ) async {
    final tts = _ControllableTtsService();

    await tester.pumpWidget(
      _harness(_gardenData(level: 'A1'), firstTime: true, tts: tts),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('garden-first-welcome-bubble')),
    );

    expect(
      find.byKey(const ValueKey('garden-first-welcome-bubble')),
      findsOneWidget,
    );
    expect(find.text('Explore Garden'), findsNothing);
    expect(find.text("Let's Talk"), findsNothing);

    await _pumpUntilSpeaking(tester, tts);
    tts.finish();
    await _pumpUntilFound(tester, find.text('Explore Garden'));

    expect(find.text('Explore Garden'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('garden-first-explore')));
    await _pumpUntilFound(tester, find.text("Let's Talk"));

    expect(find.text("Let's Talk"), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-talk-bar-layer')), findsOneWidget);
  });

  testWidgets('existing plants do not pop or play SFX on first garden load', (
    tester,
  ) async {
    final audio = _FakeAudioService();
    final data = _gardenData(
      level: 'A1',
      steps: [
        _step(level: 'A1', step: 1, name: 'First Unit', count: 1, sightings: 1),
      ],
    );

    await tester.pumpWidget(
      _harness(data, disableAnimations: false, audio: audio),
    );
    await tester.pump();

    final plantScale = tester.widget<Transform>(
      find.byKey(const ValueKey('garden-plant-scale-A1-U1-S0')),
    );
    expect(plantScale.transform.storage[0], closeTo(1, 0.001));
    expect(audio.playedSfx, isEmpty);
    expect(
      find.byKey(const ValueKey('garden-growth-reveal-card')),
      findsNothing,
    );
  });

  testWidgets('sighting increases trigger one growth pop and SFX', (
    tester,
  ) async {
    final audio = _FakeAudioService();
    final initial = _gardenData(
      level: 'A1',
      steps: [_step(level: 'A1', step: 1, name: 'First Unit', count: 1)],
    );
    final grown = _gardenData(
      level: 'A1',
      steps: [
        _step(level: 'A1', step: 1, name: 'First Unit', count: 1, sightings: 1),
      ],
    );
    final sourceProvider = StateProvider<GardenData>((ref) => initial);

    await tester.pumpWidget(
      _harness(
        initial,
        disableAnimations: false,
        audio: audio,
        gardenDataProvider: sourceProvider,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('garden-plant-scale-A1-U1-S0')),
      findsNothing,
    );
    expect(audio.playedSfx, isEmpty);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GardenScreen)),
    );
    container.read(sourceProvider.notifier).state = grown;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 999));

    expect(audio.playedSfx, isEmpty);
    expect(
      find.byKey(const ValueKey('garden-growth-reveal-card')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 901));
    await tester.pump();
    await _pumpUntilSfx(tester, audio);

    expect(container.read(gardenGrowthRevealProvider), isNotEmpty);
    expect(audio.playedSfx, contains(Sounds.newSprout));
    expect(find.text('A new skill is sprouting'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-talk-bar-layer')), findsNothing);
    final plantScale = tester.widget<Transform>(
      find.byKey(const ValueKey('garden-plant-scale-A1-U1-S0')),
    );
    expect(plantScale.transform.storage[0], isNot(closeTo(1, 0.001)));
  });

  // ── Garden switcher ──────────────────────────────────────────────────────

  group('gardenSwitcherEntries', () {
    test('early A0 → one unlocked (current) + one locked next', () {
      final entries = gardenSwitcherEntries('A0');
      expect(entries.map((e) => e.code).toList(), ['A0', 'A1']);
      expect(entries[0].isCurrent, isTrue);
      expect(entries[0].isLocked, isFalse);
      expect(entries[1].isCurrent, isFalse);
      expect(entries[1].isLocked, isTrue);
    });

    test('mid A2 → A0/A1/A2 unlocked, B1 locked, B2/C1 hidden', () {
      final entries = gardenSwitcherEntries('A2');
      expect(entries.map((e) => e.code).toList(), ['A0', 'A1', 'A2', 'B1']);
      expect(entries.firstWhere((e) => e.code == 'A2').isCurrent, isTrue);
      expect(entries.firstWhere((e) => e.code == 'B1').isLocked, isTrue);
      expect(entries.where((e) => e.code == 'B2'), isEmpty);
      expect(entries.where((e) => e.code == 'C1'), isEmpty);
    });

    test('last C1 → all six unlocked, no locked entry', () {
      final entries = gardenSwitcherEntries('C1');
      expect(entries, hasLength(6));
      expect(entries.last.code, 'C1');
      expect(entries.last.isCurrent, isTrue);
      expect(entries.any((e) => e.isLocked), isFalse);
    });

    test('unknown level falls back to first entry as current', () {
      final entries = gardenSwitcherEntries('ZZ');
      expect(entries.first.code, 'A0');
      expect(entries.first.isCurrent, isTrue);
      expect(entries[1].code, 'A1');
      expect(entries[1].isLocked, isTrue);
    });

    test('placement at B1 unlocks prior gardens and one next fog card', () {
      final entries = gardenSwitcherEntries('B1');
      expect(entries.map((e) => e.code).toList(), [
        'A0',
        'A1',
        'A2',
        'B1',
        'B2',
      ]);
      expect(entries.where((e) => e.isLocked).single.code, 'B2');
      expect(entries.firstWhere((e) => e.code == 'B1').isCurrent, isTrue);
      expect(entries.firstWhere((e) => e.code == 'A1').isLocked, isFalse);
    });
  });

  Future<void> openSwitcher(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('garden-level-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('completed-level loading keeps the selected level backdrop', (
    tester,
  ) async {
    final pending = Completer<GardenData>();
    await tester.pumpWidget(
      _harness(
        _gardenData(level: 'C1'),
        previousGardenLoader: (_) => pending.future,
        mediaSize: const Size(390, 844),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await openSwitcher(tester);

    await tester.tap(find.byKey(const ValueKey('garden-switcher-card-A1')));
    await tester.pump();

    expect(find.text('Preparing your garden...'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-backdrop-A1')), findsOneWidget);
    expect(find.byType(HomeSceneBackground), findsNothing);
    expect(find.byType(PlacementGardenBackdrop), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(_apiPreviousGarden('A1'));
  });

  testWidgets('tapping pill opens the garden switcher sheet', (tester) async {
    await _pumpGarden(tester, _gardenData(level: 'A2'));
    await openSwitcher(tester);

    expect(find.byKey(const ValueKey('garden-switcher-sheet')), findsOneWidget);
    expect(find.text("Narendra's Gardens"), findsOneWidget);
    final board = find.byKey(const ValueKey('garden-switcher-sign-board'));
    final screenWidth = tester.getSize(find.byType(GardenScreen)).width;
    expect(tester.getSize(board).height, 48);
    expect(tester.getSize(board).width, lessThan(screenWidth - 48));
    expect(tester.getCenter(board).dx, closeTo(screenWidth / 2, 0.5));
  });

  testWidgets('early A0 switcher: one unlocked current + one fog card', (
    tester,
  ) async {
    await _pumpGarden(tester, _gardenData(level: 'A0'));
    await openSwitcher(tester);

    expect(
      find.byKey(const ValueKey('garden-switcher-card-A0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('garden-switcher-card-A1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('garden-switcher-card-A2')), findsNothing);
    expect(
      find.byKey(const ValueKey('garden-switcher-youre-here')),
      findsOneWidget,
    );
  });

  testWidgets('last C1 switcher: six cards, no fog card', (tester) async {
    await _pumpGarden(tester, _gardenData(level: 'C1'));
    await openSwitcher(tester);

    for (final code in ['A0', 'A1', 'A2', 'B1', 'B2', 'C1']) {
      expect(
        find.byKey(ValueKey('garden-switcher-card-$code')),
        findsOneWidget,
        reason: 'card $code should be present',
      );
    }
    // No locked/next card beyond C1 → the fog overlay never renders.
    expect(find.byKey(const ValueKey('garden-switcher-fog')), findsNothing);
  });

  testWidgets('tapping fog card shows Zoe bubble and does not navigate', (
    tester,
  ) async {
    await _pumpGarden(tester, _gardenData(level: 'A0'));
    await openSwitcher(tester);

    await tester.tap(find.byKey(const ValueKey('garden-switcher-card-A1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('garden-switcher-bubble')),
      findsOneWidget,
    );
    expect(find.textContaining('Keep growing'), findsOneWidget);
    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('garden-switcher-bubble')))
          .dy,
      lessThanOrEqualTo(
        tester
                .getTopLeft(find.byKey(const ValueKey('garden-switcher-zoe')))
                .dy -
            4,
      ),
    );
    // "Dawn Glade" appears both on the current card and inside the bubble copy.
    expect(find.textContaining('Dawn Glade'), findsWidgets);
    // Sheet is still open — the fog card is non-navigable.
    expect(find.byKey(const ValueKey('garden-switcher-sheet')), findsOneWidget);
  });

  testWidgets('tapping an unlocked card switches the viewed garden', (
    tester,
  ) async {
    await _pumpGarden(tester, _gardenData(level: 'C1'));
    await openSwitcher(tester);

    await tester.tap(find.byKey(const ValueKey('garden-switcher-card-A1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('garden-backdrop-A1')), findsOneWidget);
    expect(find.text('Morning Meadow'), findsWidgets);
  });

  testWidgets('completed previous garden shows one-time intro and bloomed data', (
    tester,
  ) async {
    await _pumpGarden(tester, _gardenData(level: 'B1'));
    await openSwitcher(tester);

    await tester.tap(find.byKey(const ValueKey('garden-switcher-card-A1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('garden-backdrop-A1')), findsOneWidget);
    expect(find.text('Morning Meadow'), findsWidgets);
    expect(
      find.byKey(const ValueKey('garden-completed-previous-intro')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Look at this! These are things you already know. Your garden was already grown',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('garden-talk-bar-layer')), findsNothing);
    expect(
      find.byKey(const ValueKey('garden-plant-scale-U1-VOC-01')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('garden-completed-previous-explore')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntilPrefsContain(tester, _testCompletedIntroPrefsKey, 'A1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_testCompletedIntroPrefsKey), contains('A1'));

    expect(
      find.byKey(const ValueKey('garden-completed-previous-intro')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('garden-talk-bar-layer')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('garden-skill-tile-U1-VOC-01')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('garden-growth-state-bloomed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('garden-strand-chip-voc')),
      findsOneWidget,
    );
    expect(find.text('Bloomed'), findsOneWidget);
    // Real API evidence is shown for previous gardens.
    expect(find.text('What You Said'), findsOneWidget);
    expect(find.textContaining('My friend is tall and happy.'), findsWidgets);
    expect(
      find.text('Talk with Zoe to start growing this skill'),
      findsNothing,
    );
  });

  testWidgets(
    'previous garden fetch failure shows toast and returns to current garden',
    (tester) async {
      await _pumpGarden(
        tester,
        _gardenData(level: 'B1'),
        previousGardenFails: true,
      );
      await openSwitcher(tester);

      await tester.tap(find.byKey(const ValueKey('garden-switcher-card-A1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Something went wrong. Please try again later.'),
        findsOneWidget,
      );
      // Bounced back to the current garden; no previous garden, no intro.
      expect(find.byKey(const ValueKey('garden-backdrop-B1')), findsOneWidget);
      expect(find.byKey(const ValueKey('garden-backdrop-A1')), findsNothing);
      expect(
        find.byKey(const ValueKey('garden-completed-previous-intro')),
        findsNothing,
      );
    },
  );

  testWidgets('completed previous intro is not repeated in the same session', (
    tester,
  ) async {
    await _pumpGarden(tester, _gardenData(level: 'B1'));
    await openSwitcher(tester);
    await tester.tap(find.byKey(const ValueKey('garden-switcher-card-A1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.byKey(const ValueKey('garden-completed-previous-explore')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await openSwitcher(tester);
    await tester.tap(find.byKey(const ValueKey('garden-switcher-card-B1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await openSwitcher(tester);
    await tester.tap(find.byKey(const ValueKey('garden-switcher-card-A1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('garden-backdrop-A1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('garden-completed-previous-intro')),
      findsNothing,
    );
  });

  testWidgets(
    'persisted completed previous intro is not repeated after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'ella_api_user_id': _testUserId,
        _testCompletedIntroPrefsKey: ['A1'],
      });

      await _pumpGarden(tester, _gardenData(level: 'B1'));
      await openSwitcher(tester);
      await tester.tap(find.byKey(const ValueKey('garden-switcher-card-A1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('garden-backdrop-A1')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('garden-completed-previous-intro')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('garden-talk-bar-layer')),
        findsOneWidget,
      );
    },
  );

  testWidgets('current garden skips completed previous intro', (tester) async {
    await _pumpGarden(tester, _gardenData(level: 'B1'));
    expect(
      find.byKey(const ValueKey('garden-completed-previous-intro')),
      findsNothing,
    );
  });

  testWidgets(
    'stale selectedGardenLevelProvider is ignored during post-conversation reveal',
    (tester) async {
      const skillId = 'target';
      final skill = _skill(id: skillId);
      final data = _gardenData(
        level: 'B1',
        steps: [
          _stepWithSkills(step: 1, skills: [skill]),
        ],
      );

      final resolved = _postConversationResult(turnCount: 3, skillId: skillId);

      await tester.pumpWidget(
        _harness(
          data,
          postConversationReveal: resolved,
          extraOverrides: [
            selectedGardenLevelProvider.overrideWith((ref) => 'A1'),
          ],
        ),
      );
      await tester.pump();

      // Expect the current garden (B1) to render, and not the overridden/previous garden (A1)
      expect(find.byKey(const ValueKey('garden-backdrop-B1')), findsOneWidget);
      expect(find.byKey(const ValueKey('garden-backdrop-A1')), findsNothing);

      // Verify reveal/watering overlay starts playing
      expect(
        find.byKey(const ValueKey('garden-growth-spotlight-layer')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'deep-unit growth reveal scrolls plant near top and keeps card clear of CTA',
    (tester) async {
      final steps = List.generate(6, (i) {
        final skill = _skill(
          id: 'deep-skill-$i',
          text: 'Skill statement $i',
          displayText: 'Display copy for skill $i',
          sightings: 1,
          evidence: [_evidence('A short example sentence $i.')],
        );
        return _stepWithSkills(step: i + 1, skills: [skill]);
      });
      final targetSkill = steps.last.skills.first;

      await tester.pumpWidget(
        _harness(
          _gardenData(level: 'A1', steps: steps),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GardenScreen)),
      );
      container.read(gardenGrowthRevealProvider.notifier).setQueue([
        _revealItem(
          step: steps.last,
          skill: targetSkill,
          from: GardenGrowthStage.seed,
          to: GardenGrowthStage.sprout,
        ),
      ]);
      await tester.pump();
      await _pumpUntilRevealCard(tester);

      final cardTopLeft = tester.getTopLeft(
        find.byKey(const ValueKey('garden-growth-reveal-card')),
      );
      final cardBottomLeft = tester.getBottomLeft(
        find.byKey(const ValueKey('garden-growth-reveal-card')),
      );
      final plantCenter = tester.getCenter(
        find.byKey(const ValueKey('garden-plant-slot-deep-skill-5')),
      );
      final ctaTop = tester
          .getTopLeft(find.byKey(const ValueKey('garden-growth-reveal-cta')))
          .dy;

      // The 6th unit's plant requires real scrolling to reach; it should
      // still land near the top of the viewport rather than wherever the
      // scroll happened to leave it.
      expect(plantCenter.dy, lessThan(932 * 0.45));
      // The card sits close below the plant (no large empty gap) and never
      // overlaps the reveal CTA button.
      expect(cardTopLeft.dy - plantCenter.dy, greaterThan(0));
      expect(cardTopLeft.dy - plantCenter.dy, lessThan(80));
      expect(cardBottomLeft.dy, lessThan(ctaTop));
    },
  );
}
