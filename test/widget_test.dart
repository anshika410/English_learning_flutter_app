import 'package:flutter_test/flutter_test.dart';
import 'package:ella_flutter/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const EllaApp());
    expect(find.text("Let's Go"), findsOneWidget);
  });
}
