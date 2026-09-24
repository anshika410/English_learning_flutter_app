import 'package:ella_app/models/child_memory.dart';
import 'package:ella_app/providers/chat_provider.dart';
import 'package:ella_app/providers/connectivity_provider.dart';
import 'package:ella_app/providers/onboarding_provider.dart';
import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/home_screen.dart';
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
  testWidgets('HomeScreen automatically speaks recap text when rendered',
      (tester) async {
    final mockTts = _MockTtsService();
    const recapText = 'Welcome back Maya! Ready for our chat?';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith(() => _FakeChatNotifier(_testMemory(recapText))),
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
    // Advance time past the 400ms auto-speak timer
    await tester.pump(const Duration(milliseconds: 500));

    expect(mockTts.lastSpokenText, recapText);

    // Clean up timers/widgets
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Tapping Hear Again on HomeScreen re-triggers speak',
      (tester) async {
    final mockTts = _MockTtsService();
    const recapText = 'Recap line for testing hear again button';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith(() => _FakeChatNotifier(_testMemory(recapText))),
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

    mockTts.lastSpokenText = null;
    mockTts.speakingState = false;

    // Tap Hear Again button
    await tester.tap(find.byKey(const ValueKey('home-hear-again-button')));
    await tester.pump();

    expect(mockTts.lastSpokenText, recapText);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
