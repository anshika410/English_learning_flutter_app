// Unit tests for the next_topics models (TopicChoice + NextTopics) parsed from
// GET /users/me/memory.

import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/models/child_memory.dart';

void main() {
  group('TopicChoice.fromJson', () {
    test('parses all fields', () {
      final t = TopicChoice.fromJson({
        'name': 'Food I like',
        'label': 'Food',
        'icon': 'a1-04-food-i-like',
        'starter': 'What is your favourite food?',
      });
      expect(t.name, 'Food I like');
      expect(t.label, 'Food');
      expect(t.icon, 'a1-04-food-i-like');
      expect(t.starter, 'What is your favourite food?');
      expect(t.display, 'Food'); // label preferred
    });

    test('display falls back to name when label missing', () {
      final t = TopicChoice.fromJson({'name': 'My school'});
      expect(t.label, '');
      expect(t.display, 'My school');
    });
  });

  group('NextTopics.fromJson', () {
    test('parses recommended + alternatives', () {
      final n = NextTopics.fromJson({
        'recommended': {'name': 'Food I like', 'label': 'Food'},
        'alternatives': [
          {'name': 'My family', 'label': 'Family'},
          {'name': 'My school', 'label': 'School'},
          {'name': 'Sports and games', 'label': 'Sports'},
        ],
      });
      expect(n.recommended?.name, 'Food I like');
      expect(n.recommended?.display, 'Food');
      expect(n.alternatives, hasLength(3));
      expect(n.alternatives.map((a) => a.label), ['Family', 'School', 'Sports']);
    });

    test('defaults to empty on missing keys', () {
      final n = NextTopics.fromJson({});
      expect(n.recommended, isNull);
      expect(n.alternatives, isEmpty);
    });

    test('MemoryState defaults nextTopics to empty', () {
      const mem = MemoryState(childId: 'x', level: 'A1');
      expect(mem.nextTopics.recommended, isNull);
      expect(mem.nextTopics.alternatives, isEmpty);
    });
  });
}
