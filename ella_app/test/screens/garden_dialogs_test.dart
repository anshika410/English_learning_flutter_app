import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/models/garden.dart';
import 'package:ella_app/screens/child_view/widgets/garden_dialogs.dart';

GardenSkill _skill({
  String id = 'skill-1',
  Strand strand = Strand.voc,
  String text = 'Describe people and how they feel',
  String displayText = '',
  SkillStatus status = SkillStatus.locked,
  int sightings = 0,
  List<GardenEvidence> evidence = const [],
  String icon = '',
}) => GardenSkill(
  id: id,
  strand: strand,
  text: text,
  displayText: displayText,
  status: status,
  sightings: sightings,
  evidence: evidence,
  icon: icon,
);

GardenStep _step({
  String name = 'Describing the World',
  String focus = 'Go from naming things to describing them',
  String description = '',
  String displayName = '',
  String displayDescription = '',
  String icon = '',
  List<GardenSkill>? skills,
}) => GardenStep(
  step: 1,
  name: name,
  focus: focus,
  description: description,
  displayName: displayName,
  displayDescription: displayDescription,
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
  bool isPreviousGarden = false,
}) async {
  final resolvedStep = step ?? _step(skills: [skill]);
  await _pumpOpener(
    tester,
    opener: (context) =>
        () => showSkillSheet(
          context,
          resolvedStep,
          skill,
          isPreviousGarden: isPreviousGarden,
        ),
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
  test('garden model replaces legacy icons with mapped curriculum assets', () {
    final step = GardenStep.fromJson({
      'unit': 1,
      'name': 'Describing the World',
      'focus': 'Original focus fallback',
      'unit_description': 'Fresh backend unit description',
      'icon_id': 'u1-globe',
      'skills': [
        {
          'id': 'U1-VOC-01',
          'strand': 'VOC',
          'text': 'Describe people',
          'status': 'emerging',
          'sightings': 1,
          'icon_path': 'people-who-support-svgrepo-com 1',
        },
      ],
    }, level: 'A1');

    expect(step.description, 'Fresh backend unit description');
    expect(step.icon, 'assets/unit-icons/a1-a2/u1-globe.svg');
    expect(
      step.skills.single.icon,
      'assets/skill-icons/a1-a2/01-two-faces.svg',
    );

    final fallback = GardenStep.fromJson({
      'step': 2,
      'name': 'Fallback Unit',
      'focus': 'Use focus as the current unit description',
      'skills': const [],
    });
    expect(fallback.description, 'Use focus as the current unit description');
  });

  test('garden model retains backend icons for unknown curriculum content', () {
    final step = GardenStep.fromJson({
      'unit': 1,
      'name': 'Future unit',
      'focus': 'Future focus',
      'icon': 'future-unit.svg',
      'skills': [
        {
          'id': 'future-skill',
          'strand': 'VOC',
          'text': 'Future skill',
          'icon': 'future-skill.svg',
        },
      ],
    }, level: 'C2');

    expect(step.icon, 'future-unit.svg');
    expect(step.skills.single.icon, 'future-skill.svg');
  });

  test('garden model keeps canonical copy while exposing display copy', () {
    final data = GardenData.fromJson({
      'level': 'A2',
      'units': [
        {
          'unit': 2,
          'name': 'Talking about the past with more precision',
          'focus': 'Describing not just what happened, but what was happening.',
          'skills': [
            {
              'id': 'U2-GRA-02',
              'strand': 'GRA',
              'text': "I can use 'used to' to talk about past habits.",
              'status': 'locked',
              'sightings': 0,
            },
          ],
        },
      ],
    });

    final step = data.steps.single;
    final skill = step.skills.single;
    expect(step.name, 'Talking about the past with more precision');
    expect(step.displayName, 'Refining past stories');
    expect(
      step.focus,
      'Describing not just what happened, but what was happening.',
    );
    expect(
      step.displayDescription,
      'Add precision to the past — what was happening, what used to be, and how to contrast ideas.',
    );
    expect(skill.text, "I can use 'used to' to talk about past habits.");
    expect(skill.displayText, 'Talk about what you used to do');
  });

  test(
    'garden model falls back to focus when a unit description is missing',
    () {
      final data = GardenData.fromJson({
        'level': 'C1',
        'units': [
          {
            'unit': 1,
            'name': 'Mastery of vocabulary',
            'focus': 'Moving towards native-level vocabulary range.',
            'skills': const [],
          },
        ],
      });

      final step = data.steps.single;
      expect(step.displayName, 'Mastery of vocabulary');
      expect(
        step.displayDescription,
        'Moving towards native-level vocabulary range.',
      );
    },
  );

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
      find.text('Talk with Ella to grow this skill.'),
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

    expect(find.text('You Said'), findsOneWidget);
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

  testWidgets(
    'previous-garden skill sheet with evidence still shows What You Said',
    (tester) async {
      final skill = _skill(
        strand: Strand.voc,
        status: SkillStatus.owned,
        sightings: 3,
        displayText: 'Colours and numbers up to ten',
        evidence: [_evidence('My friend is tall and happy.')],
      );
      final step = _step(displayName: 'Naming the world', skills: [skill]);

      await _openSkillSheet(tester, skill, step: step, isPreviousGarden: true);

      expect(find.text('You Said'), findsOneWidget);
      expect(find.text('My friend is tall and happy.'), findsOneWidget);
      expect(
        find.text('Talk with Ella to grow this skill.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'previous-garden skill sheet without evidence ends at the chips',
    (tester) async {
      final skill = _skill(
        strand: Strand.voc,
        status: SkillStatus.owned,
        sightings: 3,
        displayText: 'Colours and numbers up to ten',
      );
      final step = _step(displayName: 'Naming the world', skills: [skill]);

      await _openSkillSheet(tester, skill, step: step, isPreviousGarden: true);

      // Unit name, skill name, strand tag and the Bloomed chip remain.
      expect(find.text('Naming the world'), findsOneWidget);
      expect(find.text('Colours and numbers up to ten'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('garden-strand-chip-voc')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('garden-growth-state-bloomed')),
        findsOneWidget,
      );

      // No empty-state block: no divider tile icon, no Talk-with-Zoe prompt.
      expect(
        find.text('Talk with Ella to grow this skill.'),
        findsNothing,
      );
      expect(find.text('You Said'), findsNothing);
    },
  );

  testWidgets(
    'current-garden skill sheet without evidence keeps the Zoe prompt',
    (tester) async {
      final skill = _skill(
        strand: Strand.voc,
        sightings: 0,
        displayText: 'Colours and numbers up to ten',
      );

      await _openSkillSheet(tester, skill);

      expect(
        find.text('Talk with Ella to grow this skill.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('skill sheet renders refreshed unit and skill copy', (
    tester,
  ) async {
    final skill = _skill(
      text: 'Canonical framework skill statement',
      displayText: 'Talk about what you used to do',
    );
    final step = _step(
      name: 'Talking about the past with more precision',
      displayName: 'Refining past stories',
      skills: [skill],
    );

    await _openSkillSheet(tester, skill, step: step);

    expect(find.text('Refining past stories'), findsOneWidget);
    expect(find.text('Talk about what you used to do'), findsOneWidget);
    expect(find.text('Canonical framework skill statement'), findsNothing);
    expect(
      find.text('Talking about the past with more precision'),
      findsNothing,
    );
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

  testWidgets('unit sheet renders refreshed unit description and skill rows', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    final step = _step(
      name: 'Speaking for longer without losing the thread',
      displayName: 'Keeping the thread',
      description: 'Canonical internal step context',
      displayDescription:
          'Build up to a full minute of connected speech — linking ideas clearly, without losing the thread.',
      skills: [
        _skill(
          id: 'skill-0',
          text: 'Canonical unit skill statement',
          displayText: 'Speak for a full minute without running out',
        ),
      ],
    );

    await _openUnitSheet(tester, step);

    expect(find.text('Keeping the thread'), findsOneWidget);
    expect(
      find.text(
        'Build up to a full minute of connected speech — linking ideas clearly, without losing the thread.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Speak for a full minute without running out'),
      findsOneWidget,
    );
    expect(find.text('Canonical internal step context'), findsNothing);
    expect(find.text('Canonical unit skill statement'), findsNothing);
  });

  testWidgets('mapped unit and skill icons keep their 48px sheet slots', (
    tester,
  ) async {
    final skill = _skill(
      id: 'U1-VOC-01',
      icon: 'assets/skill-icons/a1-a2/01-two-faces.svg',
      text: 'Describe people and how they feel',
    );
    final step = _step(
      icon: 'assets/unit-icons/a1-a2/u1-globe.svg',
      skills: [skill],
    );

    await _openSkillSheet(tester, skill, step: step);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('garden-skill-sheet-icon-U1-VOC-01')),
      ),
      const Size(48, 48),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _openUnitSheet(tester, step);
    expect(
      tester.getSize(find.byKey(const ValueKey('garden-unit-sheet-icon-1'))),
      const Size(48, 48),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('garden-unit-skill-icon-U1-VOC-01')),
      ),
      const Size(48, 48),
    );
  });
}
