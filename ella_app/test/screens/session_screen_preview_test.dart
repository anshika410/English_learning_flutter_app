import 'dart:async';

import 'package:ella_app/models/child_memory.dart';
import 'package:ella_app/models/message.dart';
import 'package:ella_app/providers/chat_provider.dart';
import 'package:ella_app/providers/garden_provider.dart';
import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/session_screen.dart';
import 'package:ella_app/screens/child_view/topic_launcher.dart';
import 'package:ella_app/screens/child_view/widgets/conversation_view.dart';
import 'package:ella_app/services/native_tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PreviewNativeTts extends NativeTtsService {
  final _progress = StreamController<TtsProgressEvent>.broadcast();
  final _done = StreamController<void>.broadcast();
  bool _speaking = false;

  @override
  Stream<TtsProgressEvent> get progressStream => _progress.stream;

  @override
  Stream<void> get doneStream => _done.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    _speaking = true;
    scheduleMicrotask(() {
      _speaking = false;
      _done.add(null);
    });
  }

  @override
  Future<void> stop() async => _speaking = false;

  @override
  bool get isSpeaking => _speaking;

  void close() {
    _progress.close();
    _done.close();
    super.dispose();
  }
}

class _CountingChatNotifier extends ChatNotifier {
  static int buildCalls = 0;

  @override
  Future<ChatState> build() async {
    buildCalls++;
    return ChatState(
      memory: const MemoryState(childId: 'preview-test', level: 'A0'),
    );
  }
}

class _ControlledNativeTts extends NativeTtsService {
  final _progress = StreamController<TtsProgressEvent>.broadcast();
  final _done = StreamController<void>.broadcast();
  Completer<void>? _activeSpeech;
  bool _speaking = false;
  bool _closed = false;
  final List<String> spokenLines = [];

  @override
  Stream<TtsProgressEvent> get progressStream => _progress.stream;

  @override
  Stream<void> get doneStream => _done.stream;

  @override
  Future<void> initialize() async {}

  void startPriorSpeech() => _speaking = true;

  @override
  Future<void> speak(String text) async {
    spokenLines.add(text);
    _speaking = true;
    final completer = Completer<void>();
    _activeSpeech = completer;
    await completer.future;
  }

  void finishSpeech() {
    if (!_speaking || _closed) return;
    _speaking = false;
    _done.add(null);
    final active = _activeSpeech;
    _activeSpeech = null;
    if (active != null && !active.isCompleted) active.complete();
  }

  @override
  Future<void> stop() async {
    final wasSpeaking = _speaking;
    _speaking = false;
    if (wasSpeaking && !_closed) _done.add(null);
  }

  @override
  bool get isSpeaking => _speaking;

  void close() {
    if (_closed) return;
    _closed = true;
    final active = _activeSpeech;
    if (active != null && !active.isCompleted) active.complete();
    _progress.close();
    _done.close();
    super.dispose();
  }
}

class _ImmediateEndChatNotifier extends ChatNotifier {
  @override
  Future<ChatState> build() async {
    final zoeMessage = ChatMessage(
      sender: MessageSender.zoe,
      text: 'Tell me about your day.',
    );
    return ChatState(
      memory: const MemoryState(childId: 'live-test', level: 'A0'),
      messages: [zoeMessage],
      status: ChatStatus.zoeSpeaking,
      currentlySpeakingMessageId: zoeMessage.id,
    );
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> endChat() async {
    final current = state.requireValue;
    ref
        .read(postConversationGardenRevealProvider.notifier)
        .begin(
          chatNumber: current.chatNumber,
          turnCount: current.turnCount,
          targetSkillIds: const [],
          before: current.memory,
        );
    ref
        .read(postConversationGardenRevealProvider.notifier)
        .resolve(
          chatNumber: current.chatNumber,
          turnCount: current.turnCount,
          targetSkillIds: const [],
          before: current.memory,
          after: current.memory,
          sessionScores: const [],
        );
    state = AsyncValue.data(
      current.copyWith(
        status: ChatStatus.idle,
        sessionEnded: true,
        clearCurrentlySpeaking: true,
      ),
    );
  }
}

class _SessionLauncher extends StatelessWidget {
  final VoidCallback onEnded;

  const _SessionLauncher({required this.onEnded});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const ValueKey('launch-preview-session'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  SessionScreen(previewMode: true, onEnded: onEnded),
            ),
          ),
          child: const Text('Launch'),
        ),
      ),
    );
  }
}

class _LiveSessionLauncher extends StatelessWidget {
  final VoidCallback onEnded;

  const _LiveSessionLauncher({required this.onEnded});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const ValueKey('launch-live-session'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SessionScreen(onEnded: onEnded),
            ),
          ),
          child: const Text('Launch live'),
        ),
      ),
    );
  }
}

class _TopicLauncherButton extends ConsumerWidget {
  const _TopicLauncherButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const ValueKey('launch-topic-preview'),
          onPressed: () => startTopicByName(context, ref, 'Preview topic'),
          child: const Text('Start topic'),
        ),
      ),
    );
  }
}

Widget _harness(_PreviewNativeTts tts, {required VoidCallback onEnded}) {
  return ProviderScope(
    overrides: [
      gardenPreviewEnabledProvider.overrideWithValue(true),
      nativeTtsProvider.overrideWithValue(tts),
      ttsProvider.overrideWithValue(tts),
      chatProvider.overrideWith(_CountingChatNotifier.new),
    ],
    child: MaterialApp(home: _SessionLauncher(onEnded: onEnded)),
  );
}

Future<ProviderContainer> _launch(
  WidgetTester tester,
  _PreviewNativeTts tts, {
  required VoidCallback onEnded,
}) async {
  await tester.pumpWidget(_harness(tts, onEnded: onEnded));
  await tester.tap(find.byKey(const ValueKey('launch-preview-session')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return ProviderScope.containerOf(tester.element(find.byType(SessionScreen)));
}

Future<void> _launchControlledLiveSession(
  WidgetTester tester,
  _ControlledNativeTts tts, {
  required VoidCallback onEnded,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nativeTtsProvider.overrideWithValue(tts),
        ttsProvider.overrideWithValue(tts),
        chatProvider.overrideWith(_ImmediateEndChatNotifier.new),
      ],
      child: MaterialApp(home: _LiveSessionLauncher(onEnded: onEnded)),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('launch-live-session')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(SessionScreen), findsOneWidget);
}

Future<void> _expectFarewellControlsNavigation(
  WidgetTester tester,
  _ControlledNativeTts tts, {
  required int Function() endedCount,
}) async {
  await tester.pump(const Duration(milliseconds: 150));

  expect(
    tts.spokenLines,
    contains('It was great talking to you. See you again later!'),
  );
  expect(
    tester.widget<ConversationView>(find.byType(ConversationView)).zoeLine,
    'It was great talking to you. See you again later!',
  );
  expect(find.byType(SessionScreen), findsOneWidget);
  expect(endedCount(), 0);

  // Immediate scoring has already marked the session ended, but it must not
  // win the navigation race while the farewell is still playing.
  await tester.pump(const Duration(seconds: 1));
  expect(find.byType(SessionScreen), findsOneWidget);
  expect(endedCount(), 0);

  tts.finishSpeech();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 299));
  expect(find.byType(SessionScreen), findsOneWidget);
  expect(endedCount(), 0);

  await tester.pump(const Duration(milliseconds: 1));
  expect(endedCount(), 1);
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byKey(const ValueKey('launch-live-session')), findsOneWidget);
  expect(endedCount(), 1);
}

void main() {
  setUp(() => _CountingChatNotifier.buildCalls = 0);

  testWidgets('topic launch routes locally when garden preview is enabled', (
    tester,
  ) async {
    final tts = _PreviewNativeTts();
    addTearDown(tts.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gardenPreviewEnabledProvider.overrideWithValue(true),
          nativeTtsProvider.overrideWithValue(tts),
          ttsProvider.overrideWithValue(tts),
          chatProvider.overrideWith(_CountingChatNotifier.new),
        ],
        child: const MaterialApp(home: _TopicLauncherButton()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('launch-topic-preview')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final session = tester.widget<SessionScreen>(find.byType(SessionScreen));
    expect(session.previewMode, isTrue);
    expect(_CountingChatNotifier.buildCalls, 0);
  });

  testWidgets(
    'normal preview End Call uses delayed watering without chat API',
    (tester) async {
      final tts = _PreviewNativeTts();
      addTearDown(tts.close);
      var ended = 0;
      final container = await _launch(tester, tts, onEnded: () => ended++);

      expect(_CountingChatNotifier.buildCalls, 0);
      await tester.tap(find.byKey(const ValueKey('conversation-end-call')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final analyzing = container.read(postConversationGardenRevealProvider);
      expect(analyzing?.isResolved, isFalse);
      expect(analyzing?.turnCount, 4);
      expect(_CountingChatNotifier.buildCalls, 0);

      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.byKey(const ValueKey('launch-preview-session')),
        findsOneWidget,
      );
      expect(ended, 1);

      await tester.pump(const Duration(seconds: 7));
      expect(
        container.read(postConversationGardenRevealProvider)?.isResolved,
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 400));
      final resolved = container.read(postConversationGardenRevealProvider);
      expect(resolved?.isResolved, isTrue);
      expect(resolved?.sessionScores.single.evidence, contains('Zoe'));
    },
  );

  testWidgets('long-press selects outcome and immediate judge timing', (
    tester,
  ) async {
    final tts = _PreviewNativeTts();
    addTearDown(tts.close);
    final container = await _launch(tester, tts, onEnded: () {});

    await tester.longPress(find.byKey(const ValueKey('conversation-end-call')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('conversation-preview-outcome-sheet')),
      findsOneWidget,
    );
    for (final outcome in GardenPreviewConversationOutcome.values) {
      expect(
        find.byKey(ValueKey('conversation-preview-outcome-${outcome.name}')),
        findsOneWidget,
      );
    }
    final initialDelay = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('conversation-preview-delay-8')),
    );
    expect(initialDelay.selected, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('conversation-preview-outcome-twoSkillGrowth')),
    );
    final immediate = find.byKey(
      const ValueKey('conversation-preview-delay-0'),
    );
    await tester.ensureVisible(immediate);
    await tester.pump();
    await tester.tap(immediate);
    final run = find.byKey(const ValueKey('conversation-preview-run'));
    await tester.ensureVisible(run);
    await tester.pump();
    await tester.tap(run);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final resolved = container.read(postConversationGardenRevealProvider);
    expect(resolved?.isResolved, isTrue);
    expect(resolved?.turnCount, 4);
    expect(resolved?.targetSkillIds, hasLength(2));
    expect(resolved?.sessionScores, hasLength(2));
    expect(_CountingChatNotifier.buildCalls, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'End Call waits for the full farewell and 300ms despite immediate scoring',
    (tester) async {
      final tts = _ControlledNativeTts()..startPriorSpeech();
      addTearDown(tts.close);
      var ended = 0;
      await _launchControlledLiveSession(tester, tts, onEnded: () => ended++);

      await tester.tap(find.byKey(const ValueKey('conversation-end-call')));
      await tester.pump();

      await _expectFarewellControlsNavigation(
        tester,
        tts,
        endedCount: () => ended,
      );
    },
  );

  testWidgets('confirmed early exit uses the protected farewell sequence', (
    tester,
  ) async {
    final tts = _ControlledNativeTts()..startPriorSpeech();
    addTearDown(tts.close);
    var ended = 0;
    await _launchControlledLiveSession(tester, tts, onEnded: () => ended++);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('need-to-go-sheet')), findsOneWidget);

    await tester.tap(find.text('Bye for now, Zoe'));
    await tester.pump(const Duration(milliseconds: 300));

    await _expectFarewellControlsNavigation(
      tester,
      tts,
      endedCount: () => ended,
    );
  });
}
