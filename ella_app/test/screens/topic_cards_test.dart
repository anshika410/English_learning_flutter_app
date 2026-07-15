import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/core/topic_preview_data.dart';
import 'package:ella_app/models/child_memory.dart';
import 'package:ella_app/providers/chat_provider.dart';
import 'package:ella_app/providers/garden_provider.dart';
import 'package:ella_app/providers/onboarding_provider.dart';
import 'package:ella_app/screens/child_view/all_topics_screen.dart';
import 'package:ella_app/screens/child_view/home_screen.dart';
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
  bool preview = false,
}) {
  return ProviderScope(
    overrides: [
      chatProvider.overrideWith(() => _FakeChatNotifier(memory)),
      onboardingProvider.overrideWith(_FakeOnboardingNotifier.new),
      gardenPreviewEnabledProvider.overrideWithValue(preview),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
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

Future<void> _pumpHome(
  WidgetTester tester,
  List<TopicChoice> topics, {
  bool preview = false,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    _harness(const HomeScreen(), _memory(topics), preview: preview),
  );
  await tester.pump();
}

Finder _labelTextFinder(Key labelKey) =>
    find.descendant(of: find.byKey(labelKey), matching: find.byType(Text));

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

  test('preview catalog matches the six backend topic levels', () {
    expect(topicPreviewCatalog.keys, ['A0', 'A1', 'A2', 'B1', 'B2', 'C1']);
    expect(topicPreviewCatalog['A0'], hasLength(11));
    for (final level in ['A1', 'A2', 'B1', 'B2', 'C1']) {
      expect(topicPreviewCatalog[level], hasLength(12));
    }
    final topics = topicPreviewCatalog.values.expand((topics) => topics);
    expect(topics, hasLength(71));
    expect(topics.map((topic) => topic.icon).toSet(), kBundledTopicIcons);
    expect(
      topicPreviewCatalog['B2']!.map((topic) => topic.display),
      containsAll(['Sustainability', 'Superstition']),
    );
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

  testWidgets('reported long labels fit both three-column layouts at 390px', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final topics = [
      _topic('sustainability', 'Sustainability'),
      _topic('superstition', 'Superstition'),
    ];

    await _pumpHome(tester, topics);

    const homeSustainabilityCard = ValueKey('home-topic-chip-Sustainability');
    const homeSuperstitionCard = ValueKey('home-topic-chip-Superstition');
    const homeSustainabilityIcon = ValueKey('home-topic-icon-Sustainability');
    const homeSuperstitionIcon = ValueKey('home-topic-icon-Superstition');
    _expectLabelFitsAt12(
      tester,
      const ValueKey('home-topic-label-Sustainability'),
    );
    _expectLabelFitsAt12(
      tester,
      const ValueKey('home-topic-label-Superstition'),
    );

    final homeFirstRect = tester.getRect(find.byKey(homeSustainabilityCard));
    final homeSecondRect = tester.getRect(find.byKey(homeSuperstitionCard));
    expect(homeSecondRect.left - homeFirstRect.right, closeTo(8, 0.01));
    expect(
      tester.getTopLeft(find.byKey(homeSustainabilityIcon)).dy -
          homeFirstRect.top,
      closeTo(12, 0.01),
    );
    expect(
      tester.getSize(find.byKey(homeSustainabilityIcon)),
      const Size.square(kTopicIconSize),
    );
    expect(
      tester
              .getRect(
                find.byKey(const ValueKey('home-topic-label-Sustainability')),
              )
              .left -
          homeFirstRect.left,
      closeTo(12, 0.01),
    );
    expect(
      tester.getTopLeft(find.byKey(homeSuperstitionIcon)).dy -
          homeSecondRect.top,
      closeTo(12, 0.01),
    );
    expect(
      tester
              .getRect(
                find.byKey(const ValueKey('home-topic-label-Superstition')),
              )
              .left -
          homeSecondRect.left,
      closeTo(12, 0.01),
    );

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

  testWidgets('home keeps an all-single-line topic row compact and equal', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await _pumpHome(tester, [
      _topic('food', 'Food'),
      _topic('school', 'School'),
    ]);

    final first = tester.getSize(
      find.byKey(const ValueKey('home-topic-chip-Food')),
    );
    final second = tester.getSize(
      find.byKey(const ValueKey('home-topic-chip-School')),
    );
    final seeMore = tester.getSize(
      find.byKey(const ValueKey('home-see-more-chip')),
    );

    expect(first.height, lessThanOrEqualTo(100));
    expect(second.height, first.height);
    expect(seeMore.height, first.height);
    expect(
      tester.getSize(find.byKey(const ValueKey('home-topic-icon-Food'))),
      const Size.square(kTopicIconSize),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('home-see-more-icon'))),
      const Size.square(kTopicIconSize),
    );
  });

  testWidgets('home expands only a mixed row and keeps icons top-aligned', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await _pumpHome(tester, [
      _topic('food', 'Food'),
      _topic('school', 'School'),
    ]);
    final compactHeight = tester
        .getSize(find.byKey(const ValueKey('home-topic-chip-Food')))
        .height;

    await _pumpHome(tester, [
      _topic('food', 'Food'),
      _topic('mental-health', 'Mental health and wellbeing'),
    ]);

    final foodCard = find.byKey(const ValueKey('home-topic-chip-Food'));
    final longCard = find.byKey(
      const ValueKey('home-topic-chip-Mental health and wellbeing'),
    );
    final seeMoreCard = find.byKey(const ValueKey('home-see-more-chip'));
    final foodHeight = tester.getSize(foodCard).height;

    expect(foodHeight, greaterThan(compactHeight));
    expect(tester.getSize(longCard).height, foodHeight);
    expect(tester.getSize(seeMoreCard).height, foodHeight);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('home-topic-icon-Food'))).dy,
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey('home-topic-icon-Mental health and wellbeing'),
            ),
          )
          .dy,
    );
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey('home-topic-icon-Mental health and wellbeing'),
        ),
      ),
      const Size.square(kTopicIconSize),
    );
  });

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

  testWidgets('preview level selector synchronizes topics, home, and garden', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await _pumpHome(tester, [
      _topic('server-food', 'Server food'),
      _topic('server-home', 'Server home'),
    ], preview: true);

    expect(
      find.byKey(const ValueKey('home-topic-chip-About me')),
      findsOneWidget,
    );
    expect(find.text('Server food'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home-topic-chip-Family')));
    await tester.pump();
    expect(find.text("Let's Talk About Family"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-see-more-chip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('topic-preview-level-selector')),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AllTopicsScreen)),
    );
    expect(container.read(gardenPreviewControllerProvider).level, 'A0');

    await tester.tap(find.byKey(const ValueKey('topic-preview-level-B2')));
    await tester.pump();
    expect(container.read(gardenPreviewControllerProvider).level, 'B2');
    expect(find.text('Sustainability'), findsOneWidget);
    expect(find.text('Superstition'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('topic-preview-level-C1')));
    await tester.pump();
    expect(container.read(gardenPreviewControllerProvider).level, 'C1');
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Globalisation'), findsOneWidget);

    Navigator.of(tester.element(find.byType(AllTopicsScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('home-topic-chip-Language')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-topic-chip-Justice')),
      findsOneWidget,
    );
  });

  testWidgets('production All Topics never shows the preview selector', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      _harness(
        const AllTopicsScreen(),
        _memory([_topic('food', 'Food'), _topic('school', 'School')]),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('topic-preview-level-selector')),
      findsNothing,
    );
  });
}
