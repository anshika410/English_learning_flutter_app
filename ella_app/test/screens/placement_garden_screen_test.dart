import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/models/child_memory.dart';
import 'package:ella_app/models/garden.dart';
import 'package:ella_app/models/placement.dart';
import 'package:ella_app/providers/chat_provider.dart';
import 'package:ella_app/providers/garden_provider.dart';
import 'package:ella_app/providers/onboarding_provider.dart';
import 'package:ella_app/providers/placement_provider.dart';
import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/garden_screen.dart';
import 'package:ella_app/screens/child_view/placement_garden_screen.dart';
import 'package:ella_app/screens/child_view/widgets/placement_garden_scene_background.dart';
import 'package:ella_app/services/audio_service.dart';
import 'package:ella_app/services/sounds.dart';
import 'package:ella_app/services/stt_tts_service.dart';

class _FakeAudioService extends AudioService {
  @override
  bool get musicEnabled => true;

  @override
  bool get sfxEnabled => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playSfx(AudioClip clip) async {}

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
  Completer<void>? _completer;
  bool _speaking = false;
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

class _FakeOnboardingNotifier extends OnboardingNotifier {
  static bool completed = false;
  static String? completedName;
  static int? completedAge;

  @override
  Future<OnboardingState> build() async =>
      const OnboardingState(done: false, name: 'Narendra', age: 10);

  @override
  Future<void> complete({required String name, required int age}) async {
    completed = true;
    completedName = name;
    completedAge = age;
    state = AsyncData(OnboardingState(done: true, name: name, age: age));
  }
}

class _FakePlacementNotifier extends PlacementNotifier {
  final bool? levelAssigned;
  _FakePlacementNotifier(this.levelAssigned);

  @override
  PlacementState build() => PlacementState(
    levelAssigned: levelAssigned,
    result: levelAssigned == true
        ? const PlacementTurnResult(isComplete: true, level: 'A1')
        : null,
  );

  void resolve(bool assigned) {
    state = PlacementState(
      levelAssigned: assigned,
      result: assigned
          ? const PlacementTurnResult(isComplete: true, level: 'A1')
          : null,
    );
  }
}

class _FakeChatNotifier extends ChatNotifier {
  @override
  Future<ChatState> build() async => ChatState(
    memory: MemoryState(childId: 'test-child', level: 'A1'),
  );
}

GardenData _gardenData() => GardenData(
  level: 'A1',
  levelLabel: '',
  theme: '',
  activeStepIndex: 1,
  recommendedTopic: '',
  steps: [
    GardenStep(
      step: 1,
      name: 'First Unit',
      focus: '',
      isCompleted: false,
      skills: [
        GardenSkill(
          id: 'A1-U1-S1',
          strand: Strand.voc,
          text: 'Skill 1',
          status: SkillStatus.locked,
          sightings: 0,
          evidence: const [],
        ),
      ],
    ),
  ],
);

Widget _harness({
  FlutterTtsService? tts,
  bool playReveal = true,
  PlacementGardenMode mode = PlacementGardenMode.onboardingReveal,
  bool? placementLevelAssigned,
}) {
  return ProviderScope(
    overrides: [
      audioProvider.overrideWithValue(_FakeAudioService()),
      ttsProvider.overrideWithValue(tts ?? _ImmediateTtsService()),
      onboardingProvider.overrideWith(_FakeOnboardingNotifier.new),
      placementProvider.overrideWith(
        () => _FakePlacementNotifier(placementLevelAssigned),
      ),
      chatProvider.overrideWith(_FakeChatNotifier.new),
      gardenProvider.overrideWith((ref) async => _gardenData()),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(size: const Size(430, 932), disableAnimations: true),
        child: child!,
      ),
      home: PlacementGardenScreen(
        mode: mode,
        onboardingName: 'Narendra',
        onboardingAge: 10,
        playReveal: playReveal,
      ),
    ),
  );
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
  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUp(() {
    _FakeOnboardingNotifier.completed = false;
    _FakeOnboardingNotifier.completedName = null;
    _FakeOnboardingNotifier.completedAge = null;
  });

  testWidgets('reveal waits for Zoe speech before Explore Garden appears', (
    tester,
  ) async {
    final tts = _ControllableTtsService();

    await tester.pumpWidget(_harness(tts: tts));

    expect(find.byType(PlacementGardenBackdrop), findsOneWidget);
    expect(find.byType(PlacementGardenWildflowers), findsOneWidget);
    expect(
      find.byKey(const ValueKey('placement-garden-tilled-tile')),
      findsOneWidget,
    );
    expect(find.text('See your Garden'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('placement-garden-reveal-bubble')),
      findsOneWidget,
    );
    expect(find.text('See your Garden'), findsNothing);

    await _pumpUntilSpeaking(tester, tts);
    tts.finish();
    await tester.pump();
    await tester.pump();

    expect(find.text('See your Garden'), findsOneWidget);
  });

  testWidgets('Explore Garden settles into the bottom Let\'s Talk bar', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump();

    expect(find.text('See your Garden'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('placement-garden-explore')));
    await tester.pumpAndSettle();

    expect(find.text('Start Talking'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('placement-garden-settled-talk')),
      findsOneWidget,
    );
  });

  testWidgets('settled Let\'s Talk completes onboarding and returns root', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(playReveal: false));
    await tester.pump();

    await tester.tap(find.text('Start Talking'));
    await tester.pump();

    expect(_FakeOnboardingNotifier.completed, isTrue);
    expect(_FakeOnboardingNotifier.completedName, 'Narendra');
    expect(_FakeOnboardingNotifier.completedAge, 10);
  });

  testWidgets('back button completes onboarding during reveal', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('placement-garden-back')));
    await tester.pump();

    expect(_FakeOnboardingNotifier.completed, isTrue);
    expect(_FakeOnboardingNotifier.completedName, 'Narendra');
    expect(_FakeOnboardingNotifier.completedAge, 10);
  });

  testWidgets('placement result waits for Zoe before See My Garden appears', (
    tester,
  ) async {
    final tts = _ControllableTtsService();

    await tester.pumpWidget(
      _harness(tts: tts, mode: PlacementGardenMode.placementResult),
    );

    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlacementGardenScreen)),
    );
    (container.read(placementProvider.notifier) as _FakePlacementNotifier)
        .resolve(true);
    await tester.pump(const Duration(milliseconds: 1200));
    await _pumpUntilFound(tester, find.textContaining('You grew your first plant'));

    expect(find.textContaining('You grew your first plant'), findsOneWidget);
    expect(find.text('See My Garden'), findsNothing);

    await _pumpUntilSpeaking(tester, tts);
    tts.finish();
    await _pumpUntilFound(tester, find.text('See My Garden'));

    expect(find.text('See My Garden'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('placement-garden-see-my-garden')),
    );
    await _pumpUntilFound(tester, find.byType(GardenScreen));

    expect(find.byType(GardenScreen), findsOneWidget);
  });

  testWidgets('placement result without a level settles in seedbed', (
    tester,
  ) async {
    final tts = _ControllableTtsService();
    await tester.pumpWidget(
      _harness(tts: tts, mode: PlacementGardenMode.placementResult),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlacementGardenScreen)),
    );
    (container.read(placementProvider.notifier) as _FakePlacementNotifier)
        .resolve(false);
    await tester.pump(const Duration(milliseconds: 1200));
    await _pumpUntilFound(
      tester,
      find.textContaining(
        'Your plant is soaking up sunshine',
      ),
    );

    await _pumpUntilSpeaking(tester, tts);
    tts.finish();
    await _pumpUntilFound(tester, find.text('See your Garden'));

    expect(find.text('See your Garden'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('placement-garden-sprout-explore')),
    );
    await tester.pumpAndSettle();

    expect(find.text('See My Garden'), findsNothing);
    expect(find.text('Start Talking'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('placement-garden-settled-talk')),
      findsOneWidget,
    );
  });
}
