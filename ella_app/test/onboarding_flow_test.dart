// Drives the OnboardingFlow step machine end-to-end (name → age → sprout →
// spotlight) without the auth gate. disableAnimations stops ZoeMascot's
// continuous animation so we can pump fixed durations instead of pumpAndSettle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/screens/child_view/onboarding/onboarding_flow.dart';

Widget _harness() => const ProviderScope(
  child: MaterialApp(
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
    expect(find.text('What should I call you?'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Aarav');
    await tester.tap(find.text('Next'));
    await tester.pump(); // step change
    await tester.pump(const Duration(milliseconds: 400)); // switcher fade

    // Age step — question interpolates the typed name.
    expect(find.text('How old are you, Aarav?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.text('Next'));
    await tester.pump(); // → sprout
    await tester.pump(const Duration(milliseconds: 400));

    // Sprout is showing; spotlight/CTA not yet.
    expect(find.text("Let's Talk"), findsNothing);

    // After the reveal delay, the spotlight step shows Zoe's line + CTA.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('your first plant'), findsOneWidget);
    expect(find.text("Let's Talk"), findsOneWidget);
  });

  testWidgets('blank name shows inline error and stays on the name step', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.text('What should I call you?'), findsOneWidget);
  });

  testWidgets('any positive age is accepted; blank age is rejected', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Aarav');
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Blank age → error, stays put.
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Please enter your age'), findsOneWidget);
    expect(find.text("Let's Talk"), findsNothing);

    // A large age (would have failed the old 3–19 check) is now accepted.
    await tester.enterText(find.byType(TextField), '45');
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text("Let's Talk"), findsOneWidget);
  });
}
