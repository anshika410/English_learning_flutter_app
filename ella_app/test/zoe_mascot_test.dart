import 'package:ella_app/screens/child_view/widgets/zoe_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a native painter-based mascot for listening mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZoeMascot(
              mode: ZoeMascotMode.listening,
              size: 180,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('zoe-native-mascot')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
