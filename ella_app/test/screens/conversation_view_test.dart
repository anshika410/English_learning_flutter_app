import 'package:ella_app/screens/child_view/widgets/conversation_view.dart';
import 'package:ella_app/screens/child_view/widgets/home_scene_background.dart';
import 'package:ella_app/screens/child_view/widgets/mascot_loading_screen.dart';
import 'package:ella_app/screens/child_view/widgets/network_error_view.dart';
import 'package:ella_app/screens/child_view/widgets/placement_garden_scene_background.dart';
import 'package:ella_app/screens/child_view/widgets/zoe_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('End Call fires on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationView(
            phase: ConvPhase.talking,
            mascotSpeaking: false,
            zoeLine: 'Tell me about your day.',
            onEnd: () => taps++,
          ),
        ),
      ),
    );

    final endCall = find.byKey(const ValueKey('conversation-end-call'));
    await tester.tap(endCall);
    expect(taps, 1);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('farewell speaking overrides the paused mascot pose', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConversationView(
            phase: ConvPhase.ending,
            mascotSpeaking: true,
            mascotPaused: true,
            zoeLine: 'It was great talking to you. See you again later!',
          ),
        ),
      ),
    );

    final mascot = tester.widget<ZoeMascot>(find.byType(ZoeMascot));
    expect(mascot.mode, ZoeMascotMode.speaking);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home scene backs conversation and loading views', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ConversationView(
              phase: ConvPhase.prepare,
              mascotSpeaking: false,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(HomeSceneBackground), findsOneWidget);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MascotLoadingScreen(message: 'Loading profile...'),
        ),
      ),
    );
    expect(find.byType(HomeSceneBackground), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: NetworkErrorView(onRetry: () {})),
      ),
    );
    expect(find.byType(HomeSceneBackground), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('loading and error views accept a garden background override', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MascotLoadingScreen(
            message: 'Preparing your garden...',
            backgroundBuilder: (child) =>
                PlacementGardenStatusBackground(child: child),
          ),
        ),
      ),
    );
    expect(find.byType(PlacementGardenBackdrop), findsOneWidget);
    expect(find.byType(HomeSceneBackground), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: NetworkErrorView(
            onRetry: () {},
            backgroundBuilder: (child) =>
                PlacementGardenStatusBackground(child: child),
          ),
        ),
      ),
    );
    expect(find.byType(PlacementGardenBackdrop), findsOneWidget);
    expect(find.byType(HomeSceneBackground), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home-scene conversation remains usable on a short phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            disableAnimations: true,
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: ConversationView(
              phase: ConvPhase.talking,
              mascotSpeaking: false,
              zoeLine: 'Tell me about your day.',
              studentLine: 'It was a good day.',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeSceneBackground), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home-scene text conversation resizes for the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 280),
            disableAnimations: true,
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: ConversationView(
              phase: ConvPhase.talking,
              mascotSpeaking: false,
              textMode: true,
              textController: controller,
              zoeLine: 'Tell me about your day.',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeSceneBackground), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
