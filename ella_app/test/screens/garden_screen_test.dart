import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/models/child_memory.dart';
import 'package:ella_app/models/garden.dart';
import 'package:ella_app/providers/chat_provider.dart';
import 'package:ella_app/providers/garden_provider.dart';
import 'package:ella_app/providers/onboarding_provider.dart';
import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/garden_screen.dart';
import 'package:ella_app/services/audio_service.dart';
import 'package:ella_app/services/sounds.dart';
import 'package:ella_app/services/stt_tts_service.dart';

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
  bool usePreviewProvider = false,
}) {
  final sourceProvider =
      gardenDataProvider ?? StateProvider<GardenData>((ref) => data);
  final overrides = <Override>[
    audioProvider.overrideWithValue(audio ?? _FakeAudioService()),
    ttsProvider.overrideWithValue(tts ?? _ImmediateTtsService()),
    chatProvider.overrideWith(() => _FakeChatNotifier(data.level)),
    onboardingProvider.overrideWith(() => _FakeOnboardingNotifier(childName)),
    gardenPreviewEnabledProvider.overrideWithValue(usePreviewProvider),
  ];
  if (!usePreviewProvider) {
    overrides.add(
      gardenProvider.overrideWith((ref) async => ref.watch(sourceProvider)),
    );
  }

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: const Size(430, 932),
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
  required int count,
  int sightings = 0,
}) => GardenStep(
  step: step,
  name: name,
  focus: '',
  displayName: displayName,
  displayDescription: displayDescription,
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

Future<void> _pumpGarden(WidgetTester tester, GardenData data) async {
  await tester.pumpWidget(_harness(data));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

GardenSkill _previewGrowthSkill(ProviderContainer container) =>
    container.read(gardenPreviewControllerProvider).steps.first.skills.first;

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

void main() {
  test('preview mock data has multiple units and mixed growth states', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final data = container.read(gardenPreviewControllerProvider);
    final skills = data.steps.expand((step) => step.skills).toList();
    final sightings = skills.map((skill) => skill.sightings).toSet();

    expect(data.steps, hasLength(5));
    expect(sightings, containsAll(<int>[0, 1, 2, 3]));
    expect(skills.any((skill) => skill.evidence.length >= 2), isTrue);
    expect(skills.any((skill) => skill.status == SkillStatus.owned), isTrue);
  });

  test('preview trigger advances growth and loops with a new skill id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(gardenPreviewControllerProvider.notifier);

    final initialId = _previewGrowthSkill(container).id;
    expect(_previewGrowthSkill(container).sightings, 0);

    controller.triggerGrowth();
    expect(_previewGrowthSkill(container).id, initialId);
    expect(_previewGrowthSkill(container).sightings, 1);

    controller.triggerGrowth();
    expect(_previewGrowthSkill(container).id, initialId);
    expect(_previewGrowthSkill(container).sightings, 2);

    controller.triggerGrowth();
    expect(_previewGrowthSkill(container).id, initialId);
    expect(_previewGrowthSkill(container).sightings, 3);

    controller.triggerGrowth();
    expect(_previewGrowthSkill(container).id, isNot(initialId));
    expect(_previewGrowthSkill(container).sightings, 1);
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

  testWidgets('preview long-press pill opens QA sheet and switches gardens', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(_gardenData(level: 'A0'), usePreviewProvider: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // The QA preview sheet now lives behind a long-press (tap opens the
    // real garden switcher instead).
    await tester.longPress(find.byKey(const ValueKey('garden-level-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('garden-preview-sheet')), findsOneWidget);
    for (final level in gardenPreviewLevels) {
      expect(find.text('${level.code} ${level.label}'), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('garden-preview-option-B2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Twilight Valley'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-backdrop-B2')), findsOneWidget);

    await tester.longPress(find.byKey(const ValueKey('garden-level-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('garden-preview-option-C1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Starlight Summit'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-backdrop-C1')), findsOneWidget);
  });

  testWidgets('preview growth trigger uses real growth animation path', (
    tester,
  ) async {
    final audio = _FakeAudioService();
    await tester.pumpWidget(
      _harness(
        _gardenData(level: 'A0'),
        usePreviewProvider: true,
        disableAnimations: false,
        audio: audio,
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GardenScreen)),
    );
    final initialSkill = _previewGrowthSkill(container);
    expect(initialSkill.sightings, 0);
    expect(
      find.byKey(ValueKey('garden-plant-scale-${initialSkill.id}')),
      findsNothing,
    );

    await tester.longPress(find.byKey(const ValueKey('garden-level-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('garden-preview-trigger-growth')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump();
    await _pumpUntilSfx(tester, audio);

    final grownSkill = _previewGrowthSkill(container);
    expect(grownSkill.sightings, 1);
    expect(grownSkill.evidence, hasLength(1));
    expect(container.read(gardenGrowthRevealProvider), isNotEmpty);
    expect(audio.playedSfx, contains(Sounds.newSprout));
    expect(find.text('A new skill is sprouting'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('garden-growth-reveal-card')),
      findsOneWidget,
    );

    final plantKey = ValueKey('garden-plant-scale-${grownSkill.id}');
    expect(find.byKey(plantKey), findsOneWidget);
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

  testWidgets('growth reveal uses refreshed skill copy on card and TTS', (
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
    expect(tts.lastSpoken, contains('Use words like yesterday, last week'));
    expect(
      tts.lastSpoken,
      isNot(contains('Canonical framework skill statement')),
    );
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

  testWidgets('unit signboard grows for text and keeps legs below board', (
    tester,
  ) async {
    await _pumpGarden(
      tester,
      _gardenData(
        level: 'A0',
        steps: [
          _step(level: 'A0', step: 1, name: 'Finding Better Words', count: 3),
          _step(
            level: 'A0',
            step: 2,
            name: 'A Very Long Unit Name That Should Wrap Gracefully',
            count: 3,
          ),
        ],
      ),
    );

    final boards = find.byKey(const ValueKey('garden-unit-sign-board'));
    final labels = find.byKey(const ValueKey('garden-unit-sign-label'));
    expect(boards, findsNWidgets(2));
    expect(labels, findsNWidgets(2));
    expect(tester.getSize(boards.at(0)).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(boards.at(1)).height, 64);

    final leftLegs = find.byKey(const ValueKey('garden-unit-sign-leg-left'));
    expect(
      tester.getTopLeft(leftLegs.at(0)).dy,
      tester.getBottomLeft(boards.at(0)).dy,
    );
    expect(
      tester.getTopLeft(leftLegs.at(1)).dy,
      tester.getBottomLeft(boards.at(1)).dy,
    );
  });

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
        const Size(48, 29),
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
          const Size(64, 54),
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

    final expectedHeights = {'sprout': 75.0, 'bud': 106.0, 'bloom': 137.0};
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
        closeTo(
          tester.getTopLeft(tile).dy +
              (tester.getBottomLeft(tile).dy - tester.getTopLeft(tile).dy) *
                  0.62,
          0.5,
        ),
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

  test('completed previous A1 garden uses local skills and all bloom', () {
    final current = _gardenData(level: 'B1');
    final projected = completedPreviousGardenData(
      currentGarden: current,
      viewedLevel: 'A1',
    );

    expect(projected.level, 'A1');
    expect(projected.steps, hasLength(5));
    expect(projected.steps.first.name, 'Describing the world');
    final skills = projected.steps.expand((step) => step.skills).toList();
    expect(skills, hasLength(20));
    expect(skills.first.id, 'A1-VOC-01');
    expect(skills.every((skill) => skill.status == SkillStatus.owned), isTrue);
    expect(skills.every((skill) => skill.sightings == 3), isTrue);
    expect(skills.every((skill) => skill.evidence.isNotEmpty), isTrue);
  });

  test(
    "completed previous A0 garden uses A0's own framework, all bloomed",
    () {
      final current = _gardenData(
        level: 'B1',
        steps: [_step(level: 'B1', step: 1, name: 'Current Unit', count: 2)],
      );
      final projected = completedPreviousGardenData(
        currentGarden: current,
        viewedLevel: 'A0',
      );

      expect(projected.level, 'A0');
      // A0's own 5 units, not the current garden's units.
      expect(projected.steps, hasLength(5));
      expect(projected.steps.first.displayName, 'Naming the world');
      expect(projected.steps.first.name, 'Naming the world');

      final skills = projected.steps.expand((step) => step.skills).toList();
      expect(skills, hasLength(20));
      expect(skills.first.id, 'U1-VOC-01');
      expect(skills.first.strand, Strand.voc);
      expect(skills.first.displayText, 'Colours and numbers up to ten');
      expect(
        skills.every((skill) => skill.status == SkillStatus.owned),
        isTrue,
      );
      expect(skills.every((skill) => skill.sightings == 3), isTrue);
      expect(skills.every((skill) => skill.evidence.isNotEmpty), isTrue);
    },
  );

  Future<void> openSwitcher(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('garden-level-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

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
      find.byKey(const ValueKey('garden-plant-scale-A1-VOC-01')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('garden-completed-previous-explore')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('garden-completed-previous-intro')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('garden-talk-bar-layer')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('garden-skill-tile-A1-VOC-01')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('garden-growth-state-bloomed')),
      findsOneWidget,
    );
    expect(find.text('Bloomed'), findsOneWidget);
    expect(
      find.text('Talk with Zoe to start growing this skill'),
      findsNothing,
    );
  });

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

  testWidgets('current garden and preview mode skip completed previous intro', (
    tester,
  ) async {
    await _pumpGarden(tester, _gardenData(level: 'B1'));
    expect(
      find.byKey(const ValueKey('garden-completed-previous-intro')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _harness(_gardenData(level: 'B1'), usePreviewProvider: true),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('garden-completed-previous-intro')),
      findsNothing,
    );
  });
}
