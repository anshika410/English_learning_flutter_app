// Drives the OnboardingFlow step machine end-to-end (name → age → sprout →
// spotlight) without the auth gate. disableAnimations stops ZoeMascot's
// continuous animation so we can pump fixed durations instead of pumpAndSettle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/onboarding/onboarding_flow.dart';
import 'package:ella_app/services/ella_api_service.dart';
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

Widget _harness() => ProviderScope(
  overrides: [
    ellaApiServiceProvider.overrideWithValue(_FakeEllaApiService()),
    ttsProvider.overrideWithValue(_FakeTtsService()),
  ],
  child: const MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Scaffold(body: OnboardingFlow()),
    ),
  ),
);

void main() {
  testWidgets('name → age → sprout → spotlight reveals "Let\'s Talk"', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    // Name step.
    expect(find.textContaining('What is your name?'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Aarav');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump(); // step change
    await tester.pump(const Duration(milliseconds: 950)); // thinking beat
    await tester.pump(const Duration(milliseconds: 400)); // switcher fade

    // Age step — question interpolates the typed name.
    expect(find.textContaining('what is your age?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump(); // → sprout
    await tester.pump(const Duration(milliseconds: 400));

    // Sprout is showing; spotlight/CTA not yet.
    expect(find.text("Let's Talk"), findsNothing);

    // After the thinking + garden reveal delays, the spotlight step shows
    // Zoe's line + CTA.
    await tester.pump(const Duration(milliseconds: 3300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('your first plant'), findsOneWidget);
    expect(find.text("Let's Talk"), findsOneWidget);
  });

  testWidgets('blank name shows inline error and stays on the name step', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();

    expect(find.text('Please tell me your name'), findsOneWidget);
    expect(find.textContaining('What is your name?'), findsOneWidget);
  });

  testWidgets('any positive age is accepted; blank age is rejected', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Aarav');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 400));

    // Blank age → error, stays put.
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();
    expect(find.text('Please tell me your age'), findsOneWidget);
    expect(find.text("Let's Talk"), findsNothing);

    // A large age (would have failed the old 3–19 check) is now accepted.
    await tester.enterText(find.byType(TextField), '45');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3700));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text("Let's Talk"), findsOneWidget);
  });
}
