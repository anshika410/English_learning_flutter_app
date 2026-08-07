// Smoke test for the early-access "You've Got a Spot" welcome screen shown
// once before onboarding for @navgurukul.org students (see RootGate in
// app.dart). disableAnimations stops the mascot/glow/leaf tickers so the
// widget tree settles without pumping real animation frames.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/core/theme_colors.dart';
import 'package:ella_app/screens/child_view/spot_access_screen.dart';
import 'package:ella_app/screens/child_view/widgets/mascot_glow.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required Size size,
    VoidCallback? onContinue,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: SpotAccessScreen(onContinue: onContinue ?? () {}),
      ),
    );
    await tester.pump();
  }

  testWidgets('SpotAccessScreen renders copy and fires onContinue', (
    tester,
  ) async {
    var continued = false;
    await pumpScreen(
      tester,
      size: const Size(390, 844),
      onContinue: () => continued = true,
    );

    final heading = tester.widget<Text>(find.text("You've Got a Spot"));
    expect(heading.style?.fontSize, 32);
    expect(
      find.text(
        'NavGurukul is providing you full access to ZoSpeak as part of your English learning',
      ),
      findsOneWidget,
    );
    expect(find.text('You are all set!'), findsOneWidget);
    final dividers = tester.widgetList<Divider>(find.byType(Divider));
    expect(dividers, hasLength(2));
    expect(
      dividers.every((divider) => divider.color == EllaColors.borderStrong),
      isTrue,
    );

    await tester.tap(find.text('Meet Zoe'));
    await tester.pump();

    expect(continued, isTrue);
  });

  for (final size in <Size>[const Size(320, 568), const Size(390, 844)]) {
    testWidgets('clouds fit and content does not overflow at $size', (
      tester,
    ) async {
      await pumpScreen(tester, size: size);

      final leftCloud = tester.getRect(
        find.byKey(const Key('spot-access-cloud-left')),
      );
      final rightCloud = tester.getRect(
        find.byKey(const Key('spot-access-cloud-right')),
      );

      expect(leftCloud.left, greaterThanOrEqualTo(0));
      expect(rightCloud.right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Meet Zoe'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  for (final reducedMotion in <bool>[true, false]) {
    testWidgets(
      'MascotGlow uses a warm halo when reducedMotion is $reducedMotion',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MascotGlow(size: 260, reducedMotion: reducedMotion),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(MascotGlow),
            matching: find.byType(Container),
          ),
        );
        final decoration = container.decoration! as BoxDecoration;
        final gradient = decoration.gradient! as RadialGradient;

        expect(gradient.colors, const <Color>[
          Color(0xCCFFE066),
          Color(0x70FFD24D),
          Color(0x00FFB84D),
        ]);
        expect(gradient.colors.last.a, 0);
        expect(
          find.descendant(
            of: find.byType(MascotGlow),
            matching: find.byType(Transform),
          ),
          reducedMotion ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
