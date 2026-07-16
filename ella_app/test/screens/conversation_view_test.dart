import 'package:ella_app/screens/child_view/widgets/conversation_view.dart';
import 'package:ella_app/screens/child_view/widgets/zoe_mascot.dart';
import 'package:flutter/material.dart';
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
}
