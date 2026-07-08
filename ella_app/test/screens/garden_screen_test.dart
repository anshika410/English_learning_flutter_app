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

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
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
  @override
  Future<OnboardingState> build() async =>
      const OnboardingState(done: true, name: 'Narendra', age: 10);
}

Widget _harness(
  GardenData data, {
  bool firstTime = false,
  bool disableAnimations = true,
  FlutterTtsService? tts,
  _FakeAudioService? audio,
  StateProvider<GardenData>? gardenDataProvider,
}) {
  final sourceProvider =
      gardenDataProvider ?? StateProvider<GardenData>((ref) => data);
  return ProviderScope(
    overrides: [
      audioProvider.overrideWithValue(audio ?? _FakeAudioService()),
      ttsProvider.overrideWithValue(tts ?? _ImmediateTtsService()),
      chatProvider.overrideWith(() => _FakeChatNotifier(data.level)),
      onboardingProvider.overrideWith(_FakeOnboardingNotifier.new),
      gardenProvider.overrideWith((ref) async => ref.watch(sourceProvider)),
    ],
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
  required int count,
  int sightings = 0,
}) => GardenStep(
  step: step,
  name: name,
  focus: '',
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

Future<void> _pumpGarden(WidgetTester tester, GardenData data) async {
  await tester.pumpWidget(_harness(data));
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

void main() {
  testWidgets('known levels render their Figma garden labels', (tester) async {
    final cases = {
      'A0': 'Dawn Glade',
      'A1': 'Morning Meadow',
      'A2': 'Midday Grove',
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

  testWidgets('future levels use backend label with A2 visual fallback', (
    tester,
  ) async {
    await _pumpGarden(
      tester,
      _gardenData(level: 'B1', theme: 'Golden Orchard'),
    );

    expect(find.text('Golden Orchard'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-backdrop-A2')), findsOneWidget);
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
    await tester.pump();

    expect(audio.playedSfx, contains(Sounds.newSprout));
    final plantScale = tester.widget<Transform>(
      find.byKey(const ValueKey('garden-plant-scale-A1-U1-S0')),
    );
    expect(plantScale.transform.storage[0], lessThan(1));
  });
}
