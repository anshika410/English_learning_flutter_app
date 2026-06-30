import 'package:ella_app/screens/child_view/session_intro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses topic-based intro when provided', () {
    final text = buildSessionIntroText(topicText: 'animals');
    expect(text, 'Today, I wanted to talk about animals. Shall we?');
  });

  test('falls back to default intro when no topic is provided', () {
    final text = buildSessionIntroText();
    expect(text, 'Ready when you are. Shall we?');
  });
}
