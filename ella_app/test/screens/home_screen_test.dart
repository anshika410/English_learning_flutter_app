import 'package:ella_app/models/child_memory.dart';
import 'package:ella_app/providers/chat_provider.dart';
import 'package:ella_app/providers/connectivity_provider.dart';
import 'package:ella_app/providers/onboarding_provider.dart';
import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/home_screen.dart';
import 'package:ella_app/screens/child_view/widgets/zoe_mascot.dart';
import 'package:ella_app/screens/child_view/widgets/topic_carousel.dart';
import 'package:ella_app/services/stt_tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockTtsService extends FlutterTtsService {
  String? lastSpokenText;
  bool speakingState = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    lastSpokenText = text;
    speakingState = true;
  }

  @override
  Future<void> stop() async {
    speakingState = false;
  }

  @override
  bool get isSpeaking => speakingState;
}

MemoryState _testMemory(String recap) => MemoryState(
      childId: 'test-child',
      level: 'A1',
      lastTimeRecap: recap,
      nextTopics: const NextTopics(
        recommended: TopicChoice(name: 'food', label: 'Food', icon: ''),
        alternatives: [],
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

void main() {
  testWidgets('HomeScreen renders mascot and topic carousel without recap card or auto-speak TTS',
      (tester) async {
    final mockTts = _MockTtsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith(() => _FakeChatNotifier(_testMemory('Some recap'))),
          onboardingProvider.overrideWith(_FakeOnboardingNotifier.new),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          ttsProvider.overrideWithValue(mockTts),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: HomeScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Mascot and topic carousel are rendered
    expect(find.byType(ZoeMascot), findsOneWidget);
    expect(find.byType(TopicCarousel), findsOneWidget);

    // Recap card and HearAgain button must NOT be present
    expect(find.byKey(const ValueKey('home-last-time-card')), findsNothing);
    expect(find.byKey(const ValueKey('home-hear-again-button')), findsNothing);

    // TTS speak should not have been triggered
    expect(mockTts.lastSpokenText, isNull);

    // Clean up
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('HomeScreen renders offline chat bubble when device is offline',
      (tester) async {
    final mockTts = _MockTtsService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith(() => _FakeChatNotifier(_testMemory('Some recap'))),
          onboardingProvider.overrideWith(_FakeOnboardingNotifier.new),
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
          ttsProvider.overrideWithValue(mockTts),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: HomeScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Offline card and message are displayed
    expect(find.byKey(const ValueKey('home-last-time-card')), findsOneWidget);
    expect(
      find.textContaining("Hey Maya, I'm having trouble connecting to the internet right now!"),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

