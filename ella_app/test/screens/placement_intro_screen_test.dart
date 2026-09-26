import 'package:ella_app/providers/connectivity_provider.dart';
import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/placement_intro_screen.dart';
import 'package:ella_app/screens/child_view/widgets/circle_icon_button.dart';
import 'package:ella_app/screens/child_view/widgets/home_shortcut_header.dart';
import 'package:ella_app/services/stt_tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ImmediateTtsService extends FlutterTtsService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  bool get isSpeaking => false;
}

void main() {
  testWidgets(
    'placement home shares the regular shortcuts and lowers Zoe beneath them',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
            ttsProvider.overrideWithValue(_ImmediateTtsService()),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(390, 844),
                disableAnimations: true,
              ),
              child: PlacementIntroScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(HomeShortcutHeader), findsOneWidget);
      expect(find.textContaining('Hi,'), findsNothing);
      expect(find.text('Garden'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      for (final key in const [
        ValueKey('home-garden-shortcut'),
        ValueKey('home-profile-shortcut'),
      ]) {
        final shortcut = tester.widget<EllaCircleIconButton>(find.byKey(key));
        expect(shortcut.diameter, 72);
        expect(shortcut.labelAsChip, isTrue);
      }

      final headerRect = tester.getRect(
        find.byKey(const ValueKey('home-shortcut-header')),
      );
      final mascotRect = tester.getRect(
        find.byKey(const ValueKey('placement-home-zoe-mascot')),
      );
      expect(mascotRect.top - headerRect.bottom, closeTo(16, 0.01));

      final hearAgainRect = tester.getRect(
        find.byKey(const ValueKey('placement-intro-hear-again-button')),
      );
      final cardRect = tester.getRect(
        find.byKey(const ValueKey('placement-home-greeting-card')),
      );
      expect(cardRect.top - hearAgainRect.bottom, closeTo(10, 0.5));
      final ctaRect = tester.getRect(
        find.byKey(const ValueKey('placement-home-talk-cta')),
      );
      expect(844 - ctaRect.bottom, closeTo(24, 0.01));

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
