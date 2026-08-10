import 'dart:async';
import 'dart:convert';

import 'package:ella_app/models/conversation_feedback.dart';
import 'package:ella_app/providers/service_providers.dart';
import 'package:ella_app/screens/child_view/feeling_check_in_screen.dart';
import 'package:ella_app/screens/child_view/widgets/zoe_mascot.dart';
import 'package:ella_app/services/ella_api_service.dart';
import 'package:ella_app/services/stt_tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTts implements TtsInterface {
  final List<String> spoken = [];
  Completer<void>? _promptCompleter;
  int stopCalls = 0;
  bool failAcknowledgement = false;
  bool _isSpeaking = false;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    _isSpeaking = true;
    if (text.startsWith('Hey ')) {
      _promptCompleter = Completer<void>();
      return _promptCompleter!.future.whenComplete(() => _isSpeaking = false);
    }
    if (failAcknowledgement) {
      _isSpeaking = false;
      throw StateError('TTS unavailable');
    }
    _isSpeaking = false;
    return Future.value();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _isSpeaking = false;
    final prompt = _promptCompleter;
    if (prompt != null && !prompt.isCompleted) prompt.complete();
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

  test('check-in cadence starts at three and repeats every three', () {
    expect(shouldShowFeelingCheckIn(1), isFalse);
    expect(shouldShowFeelingCheckIn(2), isFalse);
    expect(shouldShowFeelingCheckIn(3), isTrue);
    expect(shouldShowFeelingCheckIn(4), isFalse);
    expect(shouldShowFeelingCheckIn(5), isFalse);
    expect(shouldShowFeelingCheckIn(6), isTrue);
    expect(shouldShowFeelingCheckIn(9), isTrue);
  });

  Future<
    ({
      _FakeTts tts,
      List<Map<String, Object?>> requests,
      ValueNotifier<int> completions,
    })
  >
  pumpScreen(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool failAcknowledgement = false,
    String? studentName = 'Piyush Kumar',
    Completer<http.Response>? feelingResponse,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final requests = <Map<String, Object?>>[];
    final api = EllaApiService(
      baseUrl: 'https://example.test/api',
      client: MockClient((request) async {
        requests.add({
          'method': request.method,
          'path': request.url.path,
          'body': jsonDecode(request.body),
        });
        return feelingResponse?.future ?? http.Response(
          jsonEncode({
            'session_id': 'session-3',
            'feeling': 'great',
            'submitted_at': '2026-08-10T12:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final tts = _FakeTts()..failAcknowledgement = failAcknowledgement;
    final completions = ValueNotifier<int>(0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsProvider.overrideWithValue(tts),
          ellaApiServiceProvider.overrideWithValue(api),
        ],
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
    return (tts: tts, requests: requests, completions: completions);
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
        expect(harness.tts.spoken.last, 'Thanks for telling me.');

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

        // Bubble stays visible for ~1s more before exiting to the garden.
        await tester.pump(const Duration(milliseconds: 999));
        expect(harness.completions.value, 0);
        await tester.pump(const Duration(milliseconds: 1));
        expect(harness.completions.value, 1);
        await tester.pump();
        expect(harness.requests, hasLength(1));
        expect(harness.requests.single['method'], 'PUT');
        expect(
          harness.requests.single['path'],
          '/api/session/session-3/feeling',
        );
        expect(harness.requests.single['body'], {
          'feeling': entry.key.apiValue,
        });
      },
    );
  }

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

  testWidgets('a pending feeling request never delays Garden', (tester) async {
    final response = Completer<http.Response>();
    final harness = await pumpScreen(tester, feelingResponse: response);

    await tester.tap(find.byKey(const ValueKey('feeling-choice-okay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));

    expect(harness.completions.value, 1);
    response.complete(http.Response('{}', 200));
    await tester.pump();
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
