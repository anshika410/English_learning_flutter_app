// Drives the OnboardingFlow step machine end-to-end (name -> age -> placement
// garden reveal) without the auth gate. disableAnimations stops ZoeMascot's
// continuous animation so we can pump fixed durations instead of pumpAndSettle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/onboarding/onboarding_flow.dart';
import 'package:ella_app/screens/child_view/widgets/ella_primary_button.dart';
import 'package:ella_app/services/audio_service.dart';
import 'package:ella_app/services/ella_api_service.dart';
import 'package:ella_app/services/sounds.dart';
import 'package:ella_app/services/stt_tts_service.dart';

class _FakeEllaApiService extends EllaApiService {
  _FakeEllaApiService() : super(baseUrl: 'https://example.invalid');

  @override
  Future<({bool done, String? name, int? age})> getOnboardingState() async =>
      (done: false, name: null, age: null);

  @override
  Future<void> saveOnboardingProfile({
    required String name,
    required int age,
  }) async {}

  @override
  Future<void> saveOnboarding({required String name, required int age}) async {}

  @override
  Future<void> updateProfile({required String name, required int age}) async {}
}

class _FakeTtsService extends FlutterTtsService {
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

Widget _harness() => ProviderScope(
  overrides: [
    ellaApiServiceProvider.overrideWithValue(_FakeEllaApiService()),
    ttsProvider.overrideWithValue(_FakeTtsService()),
    audioProvider.overrideWithValue(_FakeAudioService()),
  ],
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: const MediaQueryData(size: Size(430, 932), disableAnimations: true),
      child: child!,
    ),
    home: const Scaffold(body: OnboardingFlow()),
  ),
);

void main() {
  testWidgets('name -> age pushes the existing placement garden reveal', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    // Name step.
    expect(find.textContaining('What is your name?'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-reply-send')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Aarav');
    await tester.tap(find.byKey(const ValueKey('chat-reply-send')));
    expect(find.byType(EllaIconButton), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Aarav');
    await tester.tap(find.byType(EllaIconButton));
    await tester.pump(); // step change
    await tester.pump(const Duration(milliseconds: 950)); // thinking beat
    await tester.pump(const Duration(milliseconds: 400)); // switcher fade

    // Age step — question interpolates the typed name.
    expect(find.textContaining('what is your age?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.byKey(const ValueKey('chat-reply-send')));
    await tester.tap(find.byType(EllaIconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Seedbed'), findsOneWidget);
    expect(find.text("Aarav's Garden"), findsOneWidget);
    expect(find.textContaining('your first plant'), findsOneWidget);
    expect(find.text('Explore Garden'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('placement-garden-explore')));
    await tester.pump();

    expect(find.text("Let's Talk"), findsOneWidget);
  });

  testWidgets('blank name stays on the name step', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('chat-reply-send')));
  testWidgets('invalid name shows error and stays on the name step', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), '???');
    await tester.tap(find.byType(EllaIconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));

    expect(find.textContaining("couldn't get your name"), findsNothing);
    expect(find.textContaining('What is your name?'), findsOneWidget);
  });

  testWidgets('any positive age is accepted; invalid age is rejected', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Aarav');
    await tester.tap(find.byKey(const ValueKey('chat-reply-send')));
    await tester.tap(find.byType(EllaIconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 400));

    // Blank age stays put.
    await tester.tap(find.byKey(const ValueKey('chat-reply-send')));
    await tester.pump();
    expect(find.textContaining('correct age'), findsNothing);
    expect(find.textContaining('what is your age?'), findsOneWidget);
    // Invalid age → error, stays put.
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.byType(EllaIconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    expect(find.textContaining('correct age'), findsOneWidget);
    expect(find.text("Let's Talk"), findsNothing);

    // A large age (would have failed the old 3–19 check) is now accepted.
    await tester.enterText(find.byType(TextField), '45');
    await tester.tap(find.byKey(const ValueKey('chat-reply-send')));
    await tester.tap(find.byType(EllaIconButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.text('Explore Garden'), findsOneWidget);
  });
}
