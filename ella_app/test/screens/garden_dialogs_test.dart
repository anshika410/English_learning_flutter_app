import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/models/garden.dart';
import 'package:ella_app/screens/child_view/widgets/garden_dialogs.dart';

GardenSkill _skill({
  String id = 'skill-1',
  Strand strand = Strand.voc,
  String text = 'Describe people and how they feel',
  SkillStatus status = SkillStatus.locked,
  int sightings = 0,
  List<GardenEvidence> evidence = const [],
  String icon = '',
}) => GardenSkill(
  id: id,
  strand: strand,
  text: text,
  status: status,
  sightings: sightings,
  evidence: evidence,
  icon: icon,
);

GardenStep _step({
  String name = 'Describing the World',
  String focus = 'Go from naming things to describing them',
  String description = '',
  String icon = '',
  List<GardenSkill>? skills,
}) => GardenStep(
  step: 1,
  name: name,
  focus: focus,
  description: description,
  icon: icon,
  isCompleted: false,
  skills: skills ?? [_skill()],
);

GardenData _gardenData(GardenStep step) => GardenData(
  level: 'A1',
  levelLabel: 'A1',
  theme: 'Morning Meadow',
  activeStepIndex: 0,
  recommendedTopic: '',
  steps: [step],
);

GardenEvidence _evidence(String quote) => GardenEvidence(
  quote: quote,
  confidence: 0.92,
  prompted: false,
  topic: 'cricket',
  createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
);

Future<void> _setPhoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() async => tester.binding.setSurfaceSize(null));
}

Future<void> _pumpOpener(
  WidgetTester tester, {
  required VoidCallbackBuilder opener,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-sheet'),
            onPressed: opener(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-sheet')));
  await tester.pumpAndSettle();
}

typedef VoidCallbackBuilder = VoidCallback Function(BuildContext context);

Future<void> _openSkillSheet(
  WidgetTester tester,
  GardenSkill skill, {
  GardenStep? step,
}) async {
  final resolvedStep = step ?? _step(skills: [skill]);
  await _pumpOpener(
    tester,
    opener: (context) =>
        () => showSkillSheet(context, resolvedStep, skill),
  );
}

Future<void> _openUnitSheet(WidgetTester tester, GardenStep step) async {
  await _pumpOpener(
    tester,
    opener: (context) =>
        () => showUnitSheet(context, _gardenData(step), step),
  );
}

void main() {
  test('garden model parses optional dialog icon and description fields', () {
    final step = GardenStep.fromJson({
      'unit': 1,
      'name': 'Describing the World',
      'focus': 'Original focus fallback',
      'unit_description': 'Fresh backend unit description',
      'icon_id': 'u1-globe',
      'skills': [
        {
          'id': 'voc-1',
          'strand': 'VOC',
          'text': 'Describe people',
          'status': 'emerging',
          'sightings': 1,
          'icon_path': 'people-who-support-svgrepo-com 1',
        },
      ],
    });

    expect(step.description, 'Fresh backend unit description');
    expect(step.icon, 'u1-globe');
    expect(step.skills.single.icon, 'people-who-support-svgrepo-com 1');

    final fallback = GardenStep.fromJson({
      'step': 2,
      'name': 'Fallback Unit',
      'focus': 'Use focus as the current unit description',
      'skills': const [],
    });
    expect(fallback.description, 'Use focus as the current unit description');
  });

  testWidgets('skill sheet renders all Figma growth state chips', (
    tester,
  ) async {
    final cases = [
      _skill(status: SkillStatus.locked, sightings: 0),
      _skill(id: 'sprout', status: SkillStatus.emerging, sightings: 1),
      _skill(id: 'budding', status: SkillStatus.emerging, sightings: 2),
      _skill(id: 'bloomed', status: SkillStatus.owned, sightings: 3),
    ];
    final labels = ['Seed', 'Sprout', 'Budding', 'Bloomed'];

    for (var i = 0; i < cases.length; i++) {
      await _openSkillSheet(tester, cases[i]);
      expect(find.text(labels[i]), findsOneWidget);
      expect(
        find.byKey(ValueKey('garden-growth-state-${labels[i].toLowerCase()}')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('skill sheet empty state matches Figma card sizing', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    await _openSkillSheet(tester, _skill());

    expect(
      find.byKey(const ValueKey('garden-empty-skill-message')),
      findsOneWidget,
    );
    expect(
      find.text('Talk with Zoe to start growing this skill'),
      findsOneWidget,
    );
    expect(find.text('Waiting to be planted!'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('garden-sheet-card'))).width,
      382,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('garden-sheet-board'))).height,
      48,
    );
  });

  testWidgets('skill sheet renders the first three evidence cards', (
    tester,
  ) async {
    final skill = _skill(
      status: SkillStatus.owned,
      sightings: 3,
      evidence: [
        _evidence('I am very happy talking to my family whenever I want'),
        _evidence('This was a one time chance'),
        _evidence('I used kind words to explain it'),
        _evidence('This fourth quote should stay hidden'),
      ],
    );

    await _openSkillSheet(tester, skill);

    expect(find.text('What You Said'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('garden-evidence-card-$i')), findsOneWidget);
    }
    expect(
      find.text('I am very happy talking to my family whenever I want'),
      findsOneWidget,
    );
    expect(find.text('This was a one time chance'), findsOneWidget);
    expect(find.text('I used kind words to explain it'), findsOneWidget);
    expect(find.text('This fourth quote should stay hidden'), findsNothing);
    expect(find.text('Talking about cricket'), findsWidgets);
    expect(find.text('2 days ago'), findsWidgets);
  });

  testWidgets('unit sheet shows two skills then expands with Show more', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    final step = _step(
      description:
          "Go from naming things to describing them -- people, places, and what's happening around you",
      skills: [
        _skill(id: 'skill-0', text: 'Skill 0'),
        _skill(id: 'skill-1', strand: Strand.gra, text: 'Skill 1'),
        _skill(id: 'skill-2', strand: Strand.flu, text: 'Skill 2'),
        _skill(id: 'skill-3', text: 'Skill 3'),
      ],
    );

    await _openUnitSheet(tester, step);

    expect(find.text('Describing the World'), findsOneWidget);
    expect(find.text('Skill 0'), findsOneWidget);
    expect(find.text('Skill 1'), findsOneWidget);
    expect(find.text('Skill 2'), findsNothing);
    expect(find.text('Skill 3'), findsNothing);
    expect(find.byKey(const ValueKey('garden-unit-show-more')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('garden-unit-show-more')),
    );
    await tester.tap(find.byKey(const ValueKey('garden-unit-show-more')));
    await tester.pumpAndSettle();

    expect(find.text('Skill 2'), findsOneWidget);
    expect(find.text('Skill 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-unit-show-more')), findsNothing);
  });
}
