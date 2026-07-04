// Unit tests for HomeTopic — the GET /users/me/topics card model and its
// bridge into the engine Topic used to start a session.

import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/models/home_topic.dart';

void main() {
  // The sample payload from the API spec.
  final sample = {
    'id': 'my_name_and_where_i_m_from',
    'name': "My name and where I'm from",
    'theme': 'Self',
    'description': 'Introducing yourself — name, age, city, family.',
    'icon': '👤',
    'color': '#E0EDFF',
    'highlight_color': 'rgba(45,127,249,0.08)',
    'panel_bg': 'linear-gradient(135deg,#E0EDFF,#CCE0FF)',
    'vocab_seeds': <String>[],
    'structure_targets': <String>[],
    'starters': <String>[],
  };

  group('HomeTopic.fromJson', () {
    test('parses every field, including snake_case keys', () {
      final t = HomeTopic.fromJson(sample);
      expect(t.id, 'my_name_and_where_i_m_from');
      expect(t.name, "My name and where I'm from");
      expect(t.theme, 'Self');
      expect(t.description, 'Introducing yourself — name, age, city, family.');
      expect(t.icon, '👤');
      expect(t.color, '#E0EDFF');
      expect(t.highlightColor, 'rgba(45,127,249,0.08)');
      expect(t.panelBg, 'linear-gradient(135deg,#E0EDFF,#CCE0FF)');
      expect(t.vocabSeeds, isEmpty);
      expect(t.structureTargets, isEmpty);
      expect(t.starters, isEmpty);
    });

    test('parses non-empty list fields', () {
      final t = HomeTopic.fromJson({
        'id': 'x',
        'name': 'X',
        'vocab_seeds': ['dog', 'cat'],
        'structure_targets': ['I have a…'],
        'starters': ['How many?', 'Do you have a pet?'],
      });
      expect(t.vocabSeeds, ['dog', 'cat']);
      expect(t.structureTargets, ['I have a…']);
      expect(t.starters, ['How many?', 'Do you have a pet?']);
    });

    test('tolerates missing fields with safe defaults', () {
      final t = HomeTopic.fromJson({'id': 'x', 'name': 'X'});
      expect(t.theme, '');
      expect(t.icon, '');
      expect(t.color, '');
      expect(t.starters, isEmpty);
    });
  });

  group('toEngineTopic', () {
    test('maps name→topic and joins starters, using the given level', () {
      final t = HomeTopic.fromJson({
        'id': 'my_family',
        'name': 'My family',
        'theme': 'Self',
        'starters': ['How many people?', 'Do you have a pet?'],
      });
      final engine = t.toEngineTopic('A2');
      expect(engine.level, 'A2');
      expect(engine.theme, 'Self');
      expect(engine.topic, 'My family');
      expect(engine.starters, 'How many people? / Do you have a pet?');
    });
  });
}
