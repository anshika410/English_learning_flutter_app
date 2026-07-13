import 'package:ella_app/screens/child_view/widgets/conversation_view.dart';
import 'package:ella_app/screens/child_view/widgets/zoe_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
