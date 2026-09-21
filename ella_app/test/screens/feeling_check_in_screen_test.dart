import 'dart:async';
import 'dart:convert';

import 'package:ella_app/models/conversation_feedback.dart';
import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/feeling_check_in_screen.dart';
import 'package:ella_app/screens/child_view/widgets/zoe_mascot.dart';
import 'package:ella_app/services/stt_tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTts implements TtsInterface {
  final List<String> spoken = [];
  Completer<void>? _promptCompleter;
  Completer<void>? _acknowledgementCompleter;
  bool holdAcknowledgement = false;
  int stopCalls = 0;
  bool failAcknowledgement = false;
  bool _isSpeaking = false;

  final _progressController = StreamController<TtsProgressEvent>.broadcast();
  final _doneController = StreamController<void>.broadcast();

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Stream<TtsProgressEvent> get progressStream => _progressController.stream;

  @override
  Stream<void> get doneStream => _doneController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    _isSpeaking = true;
    _progressController.add(const TtsProgressEvent(0, 0));
    if (text.startsWith('Hey ')) {
      _promptCompleter = Completer<void>();
      return _promptCompleter!.future.whenComplete(() {
        _isSpeaking = false;
        _doneController.add(null);
      });
    }
    if (failAcknowledgement) {
      _isSpeaking = false;
      _doneController.add(null);
      throw StateError('TTS unavailable');
    }
    if (holdAcknowledgement) {
      _acknowledgementCompleter = Completer<void>();
      return _acknowledgementCompleter!.future.whenComplete(
        () {
          _isSpeaking = false;
          _doneController.add(null);
        },
      );
    }
    _isSpeaking = false;
    _doneController.add(null);
    return Future.value();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _isSpeaking = false;
    _doneController.add(null);
    final prompt = _promptCompleter;
    if (prompt != null && !prompt.isCompleted) prompt.complete();
    final ack = _acknowledgementCompleter;
    if (ack != null && !ack.isCompleted) ack.complete();
  }

  void finishAcknowledgement() {
    final ack = _acknowledgementCompleter;
    if (ack != null && !ack.isCompleted) ack.complete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ella_api_access_token': 'test-token',
      'ella_api_user_id': 'user-1',
    });
  });

  test('check-in cadence starts at two and repeats every two', () {
    expect(shouldShowFeelingCheckIn(1), isFalse);
    expect(shouldShowFeelingCheckIn(2), isTrue);
    expect(shouldShowFeelingCheckIn(3), isFalse);
    expect(shouldShowFeelingCheckIn(4), isTrue);
    expect(shouldShowFeelingCheckIn(6), isTrue);
    expect(shouldShowFeelingCheckIn(9), isFalse);
  });

  Future<({_FakeTts tts, ValueNotifier<int> completions})> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool failAcknowledgement = false,
    bool holdAcknowledgement = false,
    String? studentName = 'Piyush Kumar',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final tts = _FakeTts()
      ..failAcknowledgement = failAcknowledgement
      ..holdAcknowledgement = holdAcknowledgement;
    final completions = ValueNotifier<int>(0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttsProvider.overrideWithValue(tts)],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: FeelingCheckInScreen(
              studentName: studentName,
              endContext: const ConversationEndContext(
                sessionId: 'session-3',
                conversationNumber: 3,
                turnCount: 4,
                reason: ConversationEndReason.manual,
              ),
              onComplete: () => completions.value++,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 401));
    return (tts: tts, completions: completions);
  }

  testWidgets('speaks the personalized prompt once when mounted', (
    tester,
  ) async {
    final harness = await pumpScreen(tester);

    expect(find.text('Hey Piyush!'), findsOneWidget);
    expect(find.text('How did this conversation feel?'), findsOneWidget);
    expect(harness.tts.spoken, ['Hey Piyush! How did the conversation feel?']);
    expect(
      tester.widget<ZoeMascot>(find.byType(ZoeMascot)).mode,
      ZoeMascotMode.speaking,
    );
  });

  testWidgets('uses the friendly fallback when the student name is missing', (
    tester,
  ) async {
    final harness = await pumpScreen(tester, studentName: null);

    expect(find.text('Hey there!'), findsOneWidget);
    expect(harness.tts.spoken, ['Hey there! How did the conversation feel?']);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
  });

  for (final entry in <ConversationFeeling, ZoeMascotMode>{
    ConversationFeeling.great: ZoeMascotMode.joyful,
    ConversationFeeling.okay: ZoeMascotMode.affirming,
    ConversationFeeling.notGreat: ZoeMascotMode.concerned,
  }.entries) {
    testWidgets(
      '${entry.key.apiValue} selects once, reacts, speaks, and exits',
      (tester) async {
        final harness = await pumpScreen(tester);

        await tester.tap(
          find.byKey(ValueKey('feeling-choice-${entry.key.apiValue}')),
        );
        await tester.pump();

        expect(
          tester.widget<ZoeMascot>(find.byType(ZoeMascot)).mode,
          entry.value,
        );
        expect(harness.tts.stopCalls, greaterThanOrEqualTo(1));

        final choiceGestures = tester.widgetList<GestureDetector>(
          find.descendant(
            of: find.byType(FeelingCheckInScreen),
            matching: find.byType(GestureDetector),
          ),
        );
        expect(
          choiceGestures.where((gesture) => gesture.onTap != null),
          isEmpty,
        );

        // Selection stays highlighted alone for ~1s before the
        // acknowledgement bubble appears.
        await tester.pump(const Duration(milliseconds: 999));
        expect(
          find.text('Thanks for telling me how you feel!'),
          findsNothing,
        );
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          find.text('Thanks for telling me how you feel!'),
          findsOneWidget,
        );
        expect(harness.completions.value, 0);

        // Zoe speaks the acknowledgement and returns to the reaction pose
        // once she's done — she should never stay frozen mid-reaction while
        // the TTS line is still the thing driving the mascot state.
        expect(harness.tts.spoken.last, 'Thanks for telling me how you feel!');
        expect(
          tester.widget<ZoeMascot>(find.byType(ZoeMascot)).mode,
          entry.value,
        );

        // Bubble stays visible for ~1s more before exiting to the garden.
        await tester.pump(const Duration(milliseconds: 999));
        expect(harness.completions.value, 0);
        await tester.pump(const Duration(milliseconds: 1));
        expect(harness.completions.value, 1);
        await tester.pump();

        final prefs = await SharedPreferences.getInstance();
        final stored = jsonDecode(
          prefs.getString('conversation_feeling.session-3')!,
        );
        expect(stored['feeling'], entry.key.apiValue);
      },
    );
  }

  testWidgets(
    'mascot shows the speaking mode while the acknowledgement plays',
    (tester) async {
      final harness = await pumpScreen(tester, holdAcknowledgement: true);

      await tester.tap(find.byKey(const ValueKey('feeling-choice-great')));
      await tester.pump();
      expect(
        tester.widget<ZoeMascot>(find.byType(ZoeMascot)).mode,
        ZoeMascotMode.joyful,
      );

      // Acknowledgement bubble appears and TTS starts, but hasn't finished.
      await tester.pump(const Duration(seconds: 1));
      expect(harness.tts.spoken.last, 'Thanks for telling me how you feel!');
      expect(
        tester.widget<ZoeMascot>(find.byType(ZoeMascot)).mode,
        ZoeMascotMode.speaking,
      );

      // Once Zoe finishes the line, the mascot returns to the reaction pose.
      harness.tts.finishAcknowledgement();
      await tester.pump();
      expect(
        tester.widget<ZoeMascot>(find.byType(ZoeMascot)).mode,
        ZoeMascotMode.joyful,
      );

      // Drain the final post-speech hold so no timer outlives the test.
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('TTS failure does not affect the visual pacing before exit', (
    tester,
  ) async {
    final harness = await pumpScreen(tester, failAcknowledgement: true);

    await tester.tap(find.byKey(const ValueKey('feeling-choice-great')));
    await tester.pump();
    expect(harness.completions.value, 0);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(
      find.text('Thanks for telling me how you feel!'),
      findsOneWidget,
    );
    expect(harness.completions.value, 0);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(harness.completions.value, 1);
  });

  testWidgets('disposing the screen stops active speech', (tester) async {
    final harness = await pumpScreen(tester);
    final stopsBeforeDispose = harness.tts.stopCalls;

    await tester.pumpWidget(const SizedBox());

    expect(harness.tts.stopCalls, stopsBeforeDispose + 1);
  });

  for (final size in <Size>[const Size(320, 568), const Size(390, 844)]) {
    testWidgets('does not overflow at $size with enlarged text', (
      tester,
    ) async {
      await pumpScreen(tester, size: size, textScale: 1.5);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('feeling-cloud-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('feeling-cloud-right')), findsOneWidget);
    });
  }
}
