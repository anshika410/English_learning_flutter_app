import 'dart:math' as math;

import 'package:ella_app/models/child_memory.dart';
import 'package:ella_app/screens/child_view/widgets/conversation_view.dart';
import 'package:ella_app/screens/child_view/widgets/hear_again_button.dart';
import 'package:ella_app/screens/child_view/widgets/home_scene_background.dart';
import 'package:ella_app/screens/child_view/widgets/mascot_loading_screen.dart';
import 'package:ella_app/screens/child_view/widgets/network_error_view.dart';
import 'package:ella_app/screens/child_view/widgets/placement_garden_scene_background.dart';
import 'package:ella_app/screens/child_view/widgets/topic_carousel.dart';
import 'package:ella_app/screens/child_view/widgets/topic_handoff.dart';
import 'package:ella_app/screens/child_view/widgets/topic_icon.dart';
import 'package:ella_app/screens/child_view/widgets/zoe_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sportsTopic = TopicChoice(
    name: 'Sports and games',
    label: 'Sports',
    icon: 'a1-10-sports-and-games',
  );

  test('topic flight rotates continuously anticlockwise for one full turn', () {
    final samples = [
      topicHandoffRotation(0),
      topicHandoffRotation(0.25),
      topicHandoffRotation(0.5),
      topicHandoffRotation(0.75),
      topicHandoffRotation(1),
    ];

    for (var i = 1; i < samples.length; i++) {
      expect(samples[i], lessThan(samples[i - 1]));
    }
    expect(samples.first, 0);
    expect(samples.last, closeTo(-2 * math.pi, 0.0001));
    expect(math.sin(samples.last), closeTo(0, 0.0001));
    expect(math.cos(samples.last), closeTo(1, 0.0001));
  });

  test('topic flight removes Flutter Hero easing from its spin progress', () {
    for (final progress in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
      final eased = Curves.fastOutSlowIn.transform(progress);
      expect(
        topicHandoffLinearFlightProgress(eased),
        closeTo(progress, 0.002),
      );
    }
  });

  testWidgets('topic header settles at 40px and fades in independently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ConversationView(
          phase: ConvPhase.prepare,
          topic: sportsTopic,
          animateTopicHeader: true,
          mascotSpeaking: false,
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('conversation-topic-badge'))),
      const Size.square(40),
    );
    final topicIcon = tester.widget<TopicIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('conversation-topic-badge')),
        matching: find.byType(TopicIcon),
      ),
    );
    expect(topicIcon.icon, sportsTopic.icon);
    expect(topicIcon.size, 32);
    expect(find.text('Sports'), findsOneWidget);

    final labelFade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('conversation-topic-label-fade')),
    );
    expect(labelFade.opacity.value, 0);

    await tester.pump(kTopicHandoffFlightDuration);
    await tester.pump(const Duration(milliseconds: 90));
    expect(labelFade.opacity.value, greaterThan(0));
    expect(labelFade.opacity.value, lessThan(1));

    await tester.pump(kTopicHandoffSettleDuration);
    expect(labelFade.opacity.value, 1);
  });

  testWidgets('topic badge uses the full lift dip rebound landing sequence', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ConversationView(
          phase: ConvPhase.prepare,
          topic: sportsTopic,
          animateTopicHeader: true,
          mascotSpeaking: false,
        ),
      ),
    );

    double scale() => tester
        .widget<Transform>(
          find.byKey(const ValueKey('conversation-topic-landing-scale')),
        )
        .transform
        .storage[0];
    double dy() => tester
        .widget<Transform>(
          find.byKey(const ValueKey('conversation-topic-landing-translate')),
        )
        .transform
        .storage[13];

    await tester.pump(kTopicHandoffFlightDuration);
    expect(scale(), closeTo(1, 0.001));
    expect(dy(), closeTo(0, 0.001));

    await tester.pump(const Duration(milliseconds: 126));
    expect(scale(), closeTo(1.12, 0.01));
    expect(dy(), closeTo(-5, 0.1));

    await tester.pump(const Duration(milliseconds: 97));
    expect(scale(), closeTo(0.96, 0.01));
    expect(dy(), closeTo(3, 0.1));

    await tester.pump(const Duration(milliseconds: 72));
    expect(scale(), closeTo(1.04, 0.01));
    expect(dy(), closeTo(-2, 0.1));

    await tester.pump(const Duration(milliseconds: 65));
    expect(scale(), closeTo(1, 0.001));
    expect(dy(), closeTo(0, 0.001));
  });

  testWidgets('topic badge completes its shared flight into an active chat', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: GestureDetector(
                key: const ValueKey('launch-topic-handoff'),
                onTap: () => Navigator.of(context).push(
                  PageRouteBuilder<void>(
                    transitionDuration: kTopicHandoffFlightDuration,
                    pageBuilder: (_, _, _) => const ConversationView(
                      phase: ConvPhase.talking,
                      topic: sportsTopic,
                      animateTopicHeader: true,
                      mascotSpeaking: false,
                      zoeLine: null,
                    ),
                    transitionsBuilder: (_, _, _, child) => child,
                  ),
                ),
                child: Hero(
                  tag: topicHandoffHeroTag(sportsTopic),
                  createRectTween: topicHandoffRectTween,
                  flightShuttleBuilder: buildTopicHandoffFlight,
                  child: const TopicHandoffBadge(
                    topic: sportsTopic,
                    size: 96,
                    iconSize: 72,
                    selectedSource: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('launch-topic-handoff')));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 162));
    final quarterTurn = tester.widget<Transform>(
      find.byKey(const ValueKey('topic-handoff-flight-rotation')),
    );
    expect(quarterTurn.transform.storage[0], closeTo(0, 0.1));
    expect(quarterTurn.transform.storage[1], closeTo(-1, 0.02));

    await tester.pump(const Duration(milliseconds: 163));
    final halfTurn = tester.widget<Transform>(
      find.byKey(const ValueKey('topic-handoff-flight-rotation')),
    );
    expect(halfTurn.transform.storage[0], closeTo(-1, 0.02));
    expect(halfTurn.transform.storage[1], closeTo(0, 0.1));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 325));
    await tester.pump(kTopicHandoffSettleDuration);
    expect(
      tester.getSize(find.byKey(const ValueKey('conversation-topic-badge'))),
      const Size.square(40),
    );
    expect(find.text('Sports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the centered carousel topic participates in the Hero', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopicCarousel(
            topics: const [
              sportsTopic,
              TopicChoice(name: 'Food I like', label: 'Food'),
              TopicChoice(name: 'My school', label: 'School'),
            ],
            selected: sportsTopic,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final enabledHeroModes = tester
        .widgetList<HeroMode>(find.byType(HeroMode))
        .where((mode) => mode.enabled);
    expect(enabledHeroModes, hasLength(1));
  });

  testWidgets('topic header persists while prepare content cross-fades', (
    tester,
  ) async {
    Widget view(ConvPhase phase) => MaterialApp(
      home: ConversationView(
        phase: phase,
        topic: sportsTopic,
        mascotSpeaking: phase == ConvPhase.talking,
        zoeLine: phase == ConvPhase.talking ? 'What sport do you enjoy?' : null,
      ),
    );

    await tester.pumpWidget(view(ConvPhase.prepare));
    expect(
      find.byKey(const ValueKey('conversation-prepare-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('conversation-topic-header')),
      findsOneWidget,
    );
    expect(
      tester
          .getCenter(find.byKey(const ValueKey('conversation-zoe-mascot')))
          .dx,
      closeTo(400, 0.01),
    );
    expect(
      tester
          .getCenter(find.byKey(const ValueKey('conversation-prepare-card')))
          .dx,
      closeTo(400, 0.01),
    );

    await tester.pumpWidget(view(ConvPhase.talking));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('conversation-prepare-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('conversation-active-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('conversation-topic-header')),
      findsOneWidget,
    );
    for (final mascot
        in find.byKey(const ValueKey('conversation-zoe-mascot')).evaluate()) {
      expect(
        tester.getCenter(find.byElementPredicate((e) => e == mascot)).dx,
        closeTo(400, 0.01),
      );
    }

    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const ValueKey('conversation-prepare-content')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('conversation-active-content')),
      findsOneWidget,
    );
    expect(find.text('Sports'), findsOneWidget);
  });

  testWidgets('topic conversation moves Zoe down and uses a 16px bubble gap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget view({required TopicChoice? topic}) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
        child: ConversationView(
          phase: ConvPhase.talking,
          topic: topic,
          mascotSpeaking: false,
          zoeLine: 'Spacing probe',
        ),
      ),
    );

    await tester.pumpWidget(view(topic: null));
    final placementMascot = tester.getRect(
      find.byKey(const ValueKey('conversation-zoe-mascot')),
    );
    final placementBubble = tester.getRect(
      find.byKey(const ValueKey('conversation-zoe-bubble')),
    );
    expect(placementMascot.top, closeTo(28, 0.01));
    expect(placementBubble.top - placementMascot.bottom, closeTo(18, 0.01));

    await tester.pumpWidget(view(topic: sportsTopic));
    await tester.pump();
    final topicMascot = tester.getRect(
      find.byKey(const ValueKey('conversation-zoe-mascot')),
    );
    final topicBubble = tester.getRect(
      find.byKey(const ValueKey('conversation-zoe-bubble')),
    );
    expect(topicMascot.top, closeTo(76, 0.01));
    expect(topicBubble.top - topicMascot.bottom, closeTo(16, 0.01));

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion shows the complete topic header immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ConversationView(
            phase: ConvPhase.prepare,
            topic: TopicChoice(name: 'Free Talk', label: 'Free Talk'),
            animateTopicHeader: true,
            mascotSpeaking: false,
          ),
        ),
      ),
    );

    final labelFade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('conversation-topic-label-fade')),
    );
    expect(labelFade.opacity.value, 1);
    expect(find.text('Free Talk'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('conversation-topic-badge')),
        matching: find.byIcon(Icons.chat_bubble_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('long topic header stays usable on a short scaled screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.5),
            disableAnimations: true,
          ),
          child: ConversationView(
            phase: ConvPhase.prepare,
            topic: TopicChoice(
              name: 'Artificial intelligence and the future of work',
              label: 'Artificial intelligence',
            ),
            mascotSpeaking: false,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(
      find.byKey(const ValueKey('conversation-topic-label')),
    );
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
  });

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
    expect(find.byType(SingleChildScrollView), findsWidgets);

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
    expect(find.byType(SingleChildScrollView), findsWidgets);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'renders HearAgainButton directly below ZoeMascot and removes SpeakerDotButton',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool spokeAgain = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationView(
              phase: ConvPhase.talking,
              mascotSpeaking: false,
              zoeLine: 'Welcome! How are you doing today?',
              onSpeakAgain: () {
                spokeAgain = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Reusable HearAgainButton must be rendered
      expect(find.byType(HearAgainButton), findsOneWidget);
      expect(find.text('Hear Again'), findsOneWidget);

      // Verify tapping HearAgainButton triggers onSpeakAgain callback
      await tester.tap(find.byType(HearAgainButton));
      await tester.pump();
      expect(spokeAgain, isTrue);
    },
  );

  testWidgets(
    'HearAgainButton remains visible and accessible even with very long assistant responses',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final veryLongZoeResponse = List.generate(
        30,
        (i) => 'This is line number ${i + 1} of a very long assistant response.',
      ).join('\n');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationView(
              phase: ConvPhase.talking,
              mascotSpeaking: false,
              zoeLine: veryLongZoeResponse,
              onSpeakAgain: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // HearAgainButton remains visible and mounted in viewport
      expect(find.byType(HearAgainButton), findsOneWidget);

      // Verify HearAgainButton vertical center is within screen bounds (0..844)
      final hearAgainRect = tester.getRect(find.byType(HearAgainButton));
      expect(hearAgainRect.top, greaterThan(0));
      expect(hearAgainRect.bottom, lessThan(844));
    },
  );

  testWidgets(
    'auto-scrolls speech bubble to keep highlighted words visible when text is long',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final veryLongText = List.generate(
        30,
        (i) => 'Line ${i + 1} of long assistant text',
      ).join('\n');

      final highlightTargetStart = veryLongText.indexOf('Line 28');
      final highlightTargetEnd = highlightTargetStart + 'Line 28'.length;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ConversationView(
                phase: ConvPhase.talking,
                mascotSpeaking: true,
                zoeLine: veryLongText,
                highlightStart: 0,
                highlightEnd: 5,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ConversationView(
                phase: ConvPhase.talking,
                mascotSpeaking: true,
                zoeLine: veryLongText,
                highlightStart: highlightTargetStart,
                highlightEnd: highlightTargetEnd,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final singleScrollView = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byKey(const ValueKey('conversation-zoe-bubble')),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final scrollController = singleScrollView.controller!;
      expect(scrollController.position.pixels, greaterThan(0));
    },
  );
}
