import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/models/child_memory.dart';
import 'package:ella_app/providers/chat_provider.dart';
import 'package:ella_app/providers/onboarding_provider.dart';
import 'package:ella_app/screens/child_view/all_topics_screen.dart';
import 'package:ella_app/screens/child_view/home_screen.dart';
import 'package:ella_app/screens/child_view/widgets/topic_carousel.dart';
import 'package:ella_app/screens/child_view/widgets/topic_icon.dart';

TopicChoice _topic(String name, String label) =>
    TopicChoice(name: name, label: label, icon: '');

MemoryState _memory(List<TopicChoice> topics) => MemoryState(
  childId: 'topic-card-test-child',
  level: 'A1',
  nextTopics: NextTopics(
    recommended: topics.first,
    alternatives: topics.skip(1).toList(),
  ),
);

class _FakeChatNotifier extends ChatNotifier {
  final MemoryState memory;

  _FakeChatNotifier(this.memory);

  @override
  Future<ChatState> build() async => ChatState(memory: memory);
}

class _FakeOnboardingNotifier extends OnboardingNotifier {
  @override
  Future<OnboardingState> build() async =>
      const OnboardingState(done: true, name: 'Maya', age: 10);
}

Widget _harness(
  Widget child,
  MemoryState memory, {
  double textScale = 1,
  Size size = const Size(390, 844),
  bool disableAnimations = false,
}) {
  return ProviderScope(
    overrides: [
      chatProvider.overrideWith(() => _FakeChatNotifier(memory)),
      onboardingProvider.overrideWith(_FakeOnboardingNotifier.new),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child,
      ),
    ),
  );
}

void _setPhoneViewport(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpHome(WidgetTester tester, List<TopicChoice> topics) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_harness(const HomeScreen(), _memory(topics)));
  await tester.pump();
}

Finder _labelTextFinder(Key labelKey) =>
    find.descendant(of: find.byKey(labelKey), matching: find.byType(Text));

Finder _keyStartsWith(String prefix) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(prefix),
);

void _expectLabelFitsAt12(WidgetTester tester, Key labelKey) {
  final textFinder = _labelTextFinder(labelKey);
  final text = tester.widget<Text>(textFinder);
  final paragraph = tester.renderObject<RenderParagraph>(textFinder);

  expect(text.style?.fontSize, 12);
  expect(text.style?.fontWeight, FontWeight.w700);
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason:
        '${text.data} needs ${paragraph.getMaxIntrinsicWidth(double.infinity)}px '
        'inside ${paragraph.size.width}px',
  );
}

void main() {
  setUpAll(() async {
    final synonymFont = FontLoader('Synonym')
      ..addFont(rootBundle.load('assets/fonts/Synonym-Bold.otf'));
    await synonymFont.load();
  });

  testWidgets('topic label measurement fixes every label at 12px', (
    tester,
  ) async {
    late TopicLabelLayout short;
    late TopicLabelLayout phrase;
    late TopicLabelLayout longWord;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            short = measureTopicLabel(context, text: 'Food', maxWidth: 72);
            phrase = measureTopicLabel(
              context,
              text: 'Mental health',
              maxWidth: 72,
            );
            longWord = measureTopicLabel(
              context,
              text: 'Entrepreneurship',
              maxWidth: 72,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(short.fontSize, 12);
    expect(short.didOverflow, isFalse);
    expect(phrase.height, greaterThan(short.height));
    expect(phrase.maxLines, 2);
    expect(phrase.fontSize, 12);
    expect(longWord.maxLines, 1);
    expect(longWord.fontSize, 12);
  });

  testWidgets('row padding stays at 12px then compresses no lower than 8px', (
    tester,
  ) async {
    late double widePadding;
    late double narrowPadding;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            widePadding = responsiveTopicHorizontalPadding(
              context,
              labels: const ['Sustainability', 'Superstition'],
              cardWidth: 112,
            );
            narrowPadding = responsiveTopicHorizontalPadding(
              context,
              labels: const ['Entrepreneurship'],
              cardWidth: 92,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(widePadding, 12);
    expect(narrowPadding, inInclusiveRange(8, 11.5));
  });

  testWidgets('topic labels cap enlarged system text at 14px', (tester) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _harness(
        const AllTopicsScreen(),
        _memory([
          _topic('sustainability', 'Sustainability'),
          _topic('superstition', 'Superstition'),
        ]),
        textScale: 3,
      ),
    );
    await tester.pump();

    final label = tester.widget<Text>(
      _labelTextFinder(const ValueKey('all-topics-label-sustainability')),
    );
    expect(label.style?.fontSize, kTopicLabelFontSize);
    expect(
      label.textScaler?.scale(kTopicLabelFontSize),
      kTopicLabelMaximumFontSize,
    );
  });

  testWidgets('reported long labels fit the all-topics layout at 390px', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final topics = [
      _topic('sustainability', 'Sustainability'),
      _topic('superstition', 'Superstition'),
    ];

    await tester.pumpWidget(_harness(const AllTopicsScreen(), _memory(topics)));
    await tester.pump();

    _expectLabelFitsAt12(
      tester,
      const ValueKey('all-topics-label-sustainability'),
    );
    _expectLabelFitsAt12(
      tester,
      const ValueKey('all-topics-label-superstition'),
    );

    final allTopicsFirstRect = tester.getRect(
      find.byKey(const ValueKey('all-topics-card-sustainability')),
    );
    final allTopicsSecondRect = tester.getRect(
      find.byKey(const ValueKey('all-topics-card-superstition')),
    );
    expect(
      allTopicsSecondRect.left - allTopicsFirstRect.right,
      closeTo(8, 0.01),
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(const ValueKey('all-topics-icon-sustainability')),
              )
              .dy -
          allTopicsFirstRect.top,
      closeTo(12, 0.01),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('all-topics-icon-sustainability')),
      ),
      const Size.square(kTopicIconSize),
    );
    expect(
      tester
              .getRect(
                find.byKey(const ValueKey('all-topics-label-sustainability')),
              )
              .left -
          allTopicsFirstRect.left,
      closeTo(12, 0.01),
    );
  });

  testWidgets('home carousel centres the recommended topic and drives the CTA', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await _pumpHome(tester, [
      _topic('food', 'Food'),
      _topic('school', 'School'),
      _topic('home', 'Home'),
      _topic('animals', 'Animals'),
      _topic('sports', 'Sports'),
    ]);

    // The recommended topic (first) is centred, so its pill label shows and the
    // CTA is labelled for it.
    expect(find.text('Food'), findsWidgets);
    expect(find.textContaining("Let's Talk About Food"), findsOneWidget);

    final pickLabel = tester.widget<Text>(
      find.byKey(const ValueKey('home-topic-carousel-pick-label')),
    );
    expect(pickLabel.data, "Zoe's Pick");
    expect(pickLabel.style?.fontSize, 14);

    final artworkFinder = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'home-topic-carousel-artwork-',
          ),
    );
    expect(artworkFinder, findsAtLeastNWidgets(5));

    final artworkSizes = <Size>[
      for (var i = 0; i < artworkFinder.evaluate().length; i++)
        tester.getSize(artworkFinder.at(i)),
    ];
    expect(
      artworkSizes.where((size) => size == const Size.square(72)),
      hasLength(1),
    );
    expect(
      artworkSizes.where((size) => size == const Size.square(48)).length,
      greaterThanOrEqualTo(4),
    );
    expect(find.byType(ImageFiltered), findsAtLeastNWidgets(2));

    final pageViewRect = tester.getRect(
      find.byKey(const ValueKey('home-topic-carousel-page-view')),
    );
    final circleFinder = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'home-topic-carousel-circle-',
          ),
    );
    final selectedCircle = [
      for (var i = 0; i < circleFinder.evaluate().length; i++)
        circleFinder.at(i),
    ].singleWhere((finder) => tester.getSize(finder) == const Size.square(96));
    expect(
      tester.getCenter(selectedCircle).dx,
      closeTo(pageViewRect.center.dx, 0.01),
    );

    final recapRect = tester.getRect(
      find.byKey(const ValueKey('home-last-time-card')),
    );
    final bubbleRect = tester.getRect(
      find.byKey(const ValueKey('home-last-time-bubble')),
    );
    final pickRect = tester.getRect(
      find.byKey(const ValueKey('home-topic-carousel-pick-label')),
    );
    expect(pickRect.top - recapRect.bottom, closeTo(32, 0.01));

    final zoeRect = tester.getRect(
      find.byKey(const ValueKey('home-zoe-mascot')),
    );
    expect(zoeRect.top, lessThanOrEqualTo(110));
    expect(bubbleRect.top - zoeRect.bottom, closeTo(24, 0.01));

    final ctaRect = tester.getRect(find.byKey(const ValueKey('home-talk-cta')));
    expect(844 - ctaRect.bottom, closeTo(24, 0.01));

    final circleRects = [
      for (var i = 0; i < circleFinder.evaluate().length; i++)
        (finder: circleFinder.at(i), rect: tester.getRect(circleFinder.at(i))),
    ];
    final visibleCircles =
        circleRects
            .where((entry) => entry.rect.right > 0 && entry.rect.left < 390)
            .toList()
          ..sort((a, b) => a.rect.center.dx.compareTo(b.rect.center.dx));
    expect(visibleCircles, hasLength(greaterThanOrEqualTo(5)));

    final selectedRect = tester.getRect(selectedCircle);
    final leftNeighbour = visibleCircles.lastWhere(
      (entry) => entry.rect.center.dx < selectedRect.center.dx,
    );
    final rightNeighbour = visibleCircles.firstWhere(
      (entry) => entry.rect.center.dx > selectedRect.center.dx,
    );
    expect(selectedRect.left - leftNeighbour.rect.right, closeTo(24, 0.01));
    expect(rightNeighbour.rect.left - selectedRect.right, closeTo(24, 0.01));
    expect(
      selectedRect.center.dx - leftNeighbour.rect.center.dx,
      closeTo(106, 0.01),
    );
    expect(
      rightNeighbour.rect.center.dx - selectedRect.center.dx,
      closeTo(106, 0.01),
    );
    expect(
      leftNeighbour.rect.center.dy - selectedRect.center.dy,
      closeTo(12, 0.01),
    );
    expect(
      rightNeighbour.rect.center.dy - selectedRect.center.dy,
      closeTo(12, 0.01),
    );

    final leftOuter = visibleCircles.firstWhere(
      (entry) => entry.rect.center.dx < leftNeighbour.rect.center.dx,
    );
    final rightOuter = visibleCircles.lastWhere(
      (entry) => entry.rect.center.dx > rightNeighbour.rect.center.dx,
    );
    expect(
      leftOuter.rect.center.dy - selectedRect.center.dy,
      closeTo(24, 0.01),
    );
    expect(
      rightOuter.rect.center.dy - selectedRect.center.dy,
      closeTo(24, 0.01),
    );

    String itemSuffix(Finder circle) {
      final key = tester.widget(circle).key! as ValueKey<String>;
      return key.value.replaceFirst('home-topic-carousel-circle-', '');
    }

    final selectedLabelRect = tester.getRect(
      find.byKey(
        ValueKey('home-topic-carousel-label-${itemSuffix(selectedCircle)}'),
      ),
    );
    final neighbourLabelRect = tester.getRect(
      find.byKey(
        ValueKey(
          'home-topic-carousel-label-${itemSuffix(rightNeighbour.finder)}',
        ),
      ),
    );
    expect(selectedLabelRect.top - selectedRect.bottom, closeTo(6, 0.01));
    expect(
      neighbourLabelRect.top - rightNeighbour.rect.bottom,
      closeTo(6, 0.01),
    );

    expect(
      find.byKey(const ValueKey('home-topic-carousel-arc')),
      findsOneWidget,
    );

    final itemOpacities = tester
        .widgetList<Opacity>(_keyStartsWith('home-topic-carousel-item-'))
        .map((widget) => widget.opacity);
    expect(
      itemOpacities.any((opacity) => (opacity - 0.55).abs() < 0.01),
      isTrue,
    );
  });

  testWidgets('home carousel swipes one topic at a time in both directions', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final topics = [
      _topic('food', 'Food'),
      _topic('school', 'School'),
      _topic('home', 'Home'),
      _topic('animals', 'Animals'),
      _topic('sports', 'Sports'),
    ];
    final selectedNames = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 342,
                child: TopicCarousel(
                  topics: topics,
                  selected: topics.first,
                  onSelect: (topic) => selectedNames.add(topic.name),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final carousel = find.byKey(
      const ValueKey('home-topic-carousel-page-view'),
    );
    await tester.drag(carousel, const Offset(-90, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(selectedNames, ['school']);

    await tester.drag(carousel, const Offset(90, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(selectedNames, ['school', 'food']);
  });

  testWidgets("home carousel shows Zoe's Pick label only for Zoe's pick topic", (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final topics = [
      _topic('food', 'Food'),
      _topic('school', 'School'),
      _topic('home', 'Home'),
      _topic('animals', 'Animals'),
      _topic('sports', 'Sports'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 342,
                child: TopicCarousel(
                  topics: topics,
                  selected: topics.first,
                  zoePick: topics.first,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final pointerFinder = find.byKey(
      const ValueKey('home-topic-carousel-pointer'),
    );
    expect(pointerFinder, findsOneWidget);

    final labelFinder = find.byKey(
      const ValueKey('home-topic-carousel-pick-label'),
    );
    final opacityFinder = find.ancestor(
      of: labelFinder,
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacityFinder.first).opacity, 1.0);

    final carousel = find.byKey(
      const ValueKey('home-topic-carousel-page-view'),
    );

    // Swipe to Topic B (School)
    await tester.drag(carousel, const Offset(-106, 0));
    await tester.pumpAndSettle();
    expect(pointerFinder, findsOneWidget);
    expect(tester.widget<Opacity>(opacityFinder.first).opacity, 0.0);

    // Swipe back to Topic A (Food)
    await tester.drag(carousel, const Offset(106, 0));
    await tester.pumpAndSettle();
    expect(pointerFinder, findsOneWidget);
    expect(tester.widget<Opacity>(opacityFinder.first).opacity, 1.0);
  });

  testWidgets('home carousel interpolates the arc while dragging', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final topics = [
      _topic('food', 'Food'),
      _topic('school', 'School'),
      _topic('home', 'Home'),
      _topic('animals', 'Animals'),
      _topic('sports', 'Sports'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 342,
                child: TopicCarousel(
                  topics: topics,
                  selected: topics.first,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final carousel = find.byKey(
      const ValueKey('home-topic-carousel-page-view'),
    );
    final circles = _keyStartsWith('home-topic-carousel-circle-');
    final initialSelected = [
      for (var i = 0; i < circles.evaluate().length; i++) circles.at(i),
    ].singleWhere((finder) => tester.getSize(finder) == const Size.square(96));
    final initialCenterY = tester.getCenter(initialSelected).dy;

    final gesture = await tester.startGesture(tester.getCenter(carousel));
    await gesture.moveBy(const Offset(-53, 0));
    await tester.pump();

    final halfwayCircles = [
      for (var i = 0; i < circles.evaluate().length; i++) circles.at(i),
    ].where((finder) => (tester.getSize(finder).width - 82).abs() < 0.01);
    expect(halfwayCircles, hasLength(2));
    for (final circle in halfwayCircles) {
      expect(tester.getCenter(circle).dy, closeTo(initialCenterY + 6, 0.01));
    }

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('home carousel keeps ordinary multi-word labels on one line', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final topics = [
      _topic('fake-news', 'Fake news'),
      _topic('old-vs-new', 'Old vs new'),
      _topic('ai-work', 'AI and work'),
      _topic('mental-health', 'Mental health and wellbeing'),
      _topic('sports', 'Sports'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 342,
                child: TopicCarousel(
                  topics: topics,
                  selected: topics.first,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final label in ['Fake news', 'Old vs new', 'AI and work']) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      expect(tester.getSize(text).height, lessThan(24));
    }

    final longLabel = find.text('Mental health and wellbeing');
    expect(longLabel, findsOneWidget);
    expect(tester.getSize(longLabel).height, lessThanOrEqualTo(44));
  });

  testWidgets(
    'home carousel handles long labels and reduced motion on a short phone',
    (tester) async {
      const size = Size(320, 700);
      _setPhoneViewport(tester, size: size);
      final topics = [
        _topic('entrepreneurship', 'Entrepreneurship'),
        _topic('mental-health', 'Mental health and wellbeing'),
        _topic('sustainability', 'Sustainability'),
        _topic('superstition', 'Superstition'),
        _topic('future-generations', 'Future generations'),
      ];

      await tester.pumpWidget(
        _harness(
          const HomeScreen(),
          _memory(topics),
          textScale: 1.3,
          size: size,
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('home-topic-carousel-pick-label')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-topic-carousel-page-view')),
        findsOneWidget,
      );
      final visibleItemCount = tester
          .widgetList<Opacity>(_keyStartsWith('home-topic-carousel-item-'))
          .where((widget) => widget.opacity > 0.01)
          .length;
      expect(visibleItemCount, 3);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-topic-carousel')),
          matching: find.byType(ImageFiltered),
        ),
        findsNothing,
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    },
  );

  testWidgets(
    'all topics calculates compact and mixed row heights separately',
    (tester) async {
      _setPhoneViewport(tester);
      final topics = [
        _topic('food', 'Food'),
        _topic('school', 'School'),
        _topic('home', 'Home'),
        _topic('animals', 'Animals'),
        _topic('mental-health', 'Mental health and wellbeing'),
        _topic('sports', 'Sports'),
      ];

      await tester.pumpWidget(
        _harness(const AllTopicsScreen(), _memory(topics)),
      );
      await tester.pump();

      final compactRow = find.byKey(const ValueKey('all-topics-row-0'));
      final mixedRow = find.byKey(const ValueKey('all-topics-row-1'));
      expect(
        tester.getSize(mixedRow).height,
        greaterThan(tester.getSize(compactRow).height),
      );

      final animalsCard = find.byKey(const ValueKey('all-topics-card-animals'));
      final mentalHealthCard = find.byKey(
        const ValueKey('all-topics-card-mental-health'),
      );
      expect(
        tester.getSize(animalsCard).height,
        tester.getSize(mentalHealthCard).height,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('all-topics-icon-animals')))
            .dy,
        tester
            .getTopLeft(
              find.byKey(const ValueKey('all-topics-icon-mental-health')),
            )
            .dy,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('all-topics-icon-mental-health')),
        ),
        const Size.square(kTopicIconSize),
      );
    },
  );

  testWidgets('narrow text-scaled topic cards do not overflow', (tester) async {
    _setPhoneViewport(tester, size: const Size(320, 700));
    final topics = [
      _topic('entrepreneurship', 'Entrepreneurship'),
      _topic('mental-health', 'Mental health'),
      _topic('food', 'Food'),
    ];

    await tester.pumpWidget(
      _harness(const AllTopicsScreen(), _memory(topics), textScale: 1.3),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('all-topics-icon-entrepreneurship')),
      ),
      const Size.square(kTopicIconSize),
    );
  });
}
