import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/models/child_memory.dart';
import 'package:ella_app/providers/chat_provider.dart';
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

Widget _harness(Widget child, MemoryState memory, {double textScale = 1}) {
  return ProviderScope(
    overrides: [
      chatProvider.overrideWith(() => _FakeChatNotifier(memory)),
      onboardingProvider.overrideWith(_FakeOnboardingNotifier.new),
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

Future<void> _pumpHome(WidgetTester tester, List<TopicChoice> topics) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_harness(const HomeScreen(), _memory(topics)));
  await tester.pump();
}

void main() {
  testWidgets('topic label measurement wraps phrases and shrinks long words', (
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

    expect(short.fontSize, 16);
    expect(phrase.height, greaterThan(short.height));
    expect(phrase.maxLines, 2);
    expect(longWord.maxLines, 1);
    expect(longWord.fontSize, lessThan(16));
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

    expect(first.height, lessThan(100));
    expect(second.height, first.height);
    expect(seeMore.height, first.height);
    expect(
      tester.getSize(find.byKey(const ValueKey('home-topic-icon-Food'))),
      const Size.square(53),
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
      const Size.square(53),
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
        const Size.square(53),
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
      const Size.square(53),
    );
  });
}
