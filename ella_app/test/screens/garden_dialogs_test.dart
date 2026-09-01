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

GardenEvidence _evidence(String quote, {int ageDays = 2}) => GardenEvidence(
  quote: quote,
  confidence: 0.92,
  prompted: false,
  topic: 'cricket',
  createdAt: DateTime.now().subtract(Duration(days: ageDays, hours: 1)),
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

  testWidgets('skill sheet renders the four-stage growth stepper', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    await _openSkillSheet(
      tester,
      _skill(id: 'bud', status: SkillStatus.emerging, sightings: 2),
    );

    // All four stages render, once each, with the "Bud" label (not "Budding").
    expect(find.byKey(const ValueKey('garden-skill-stepper')), findsOneWidget);
    for (final key in ['seed', 'sprout', 'bud', 'bloom']) {
      expect(find.byKey(ValueKey('garden-step-$key')), findsOneWidget);
    }
    expect(find.text('Seed'), findsOneWidget);
    expect(find.text('Sprout'), findsOneWidget);
    expect(find.text('Bud'), findsOneWidget);
    expect(find.text('Bloom'), findsOneWidget);
    expect(find.text('Budding'), findsNothing);
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
      find.text(
        'This plant grows when you use this skill in your conversations',
      ),
      findsOneWidget,
    );
    expect(find.text('Waiting to be planted!'), findsNothing);
    // The empty sheet still shows the progression stepper at Seed.
    expect(find.byKey(const ValueKey('garden-skill-stepper')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('garden-sheet-card'))).width,
      382,
    );
    final boardSize = tester.getSize(
      find.byKey(const ValueKey('garden-sheet-board')),
    );
    expect(boardSize.height, 40);
    // 70% of the sheet card's width (382 on this test surface).
    expect(boardSize.width, closeTo(382 * 0.7, 0.5));
  });

  testWidgets('skill sheet shows the latest evidence and expands the rest', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    final skill = _skill(
      status: SkillStatus.owned,
      sightings: 3,
      evidence: [
        _evidence(
          'I am very happy talking to my family whenever I want',
          ageDays: 1,
        ),
        _evidence('This was a one time chance', ageDays: 3),
        _evidence('I used kind words to explain it', ageDays: 5),
      ],
    );

    await _openSkillSheet(tester, skill);

    // Collapsed: heading + only the newest (1-day-old) example, plus a link.
    expect(find.text('You used this'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('garden-evidence-card-0')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('garden-evidence-card-1')), findsNothing);
    expect(
      find.text('I am very happy talking to my family whenever I want'),
      findsOneWidget,
    );
    expect(find.text('This was a one time chance'), findsNothing);
    expect(find.text('See 2 more ways you used this skill'), findsOneWidget);

    // Tapping the link reveals the rest inline and hides the link.
    await tester.ensureVisible(
      find.byKey(const ValueKey('garden-evidence-see-more')),
    );
    await tester.tap(find.byKey(const ValueKey('garden-evidence-see-more')));
    await tester.pumpAndSettle();

    expect(find.text('This was a one time chance'), findsOneWidget);
    expect(find.text('I used kind words to explain it'), findsOneWidget);
    expect(find.textContaining('more ways you used this skill'), findsNothing);
    expect(find.text('Talking about cricket'), findsWidgets);
    expect(find.text('1 day ago'), findsWidgets);

    // Expanding the evidence never scrolls the dialog chrome off-screen.
    final close = find.byKey(const ValueKey('garden-sheet-close'));
    expect(close, findsOneWidget);
    expect(tester.getRect(close).bottom, lessThanOrEqualTo(932));

    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('garden-sheet-card')), findsNothing);
  });

  testWidgets(
    'expanded short evidence wraps its content instead of filling the cap',
    (tester) async {
      await _setPhoneSurface(tester);
      final skill = _skill(
        status: SkillStatus.owned,
        sightings: 3,
        evidence: [
          _evidence('I explained my answer clearly.', ageDays: 1),
          _evidence('I asked a helpful question.', ageDays: 2),
        ],
      );

      await _openSkillSheet(tester, skill);
      final card = find.byKey(const ValueKey('garden-sheet-card'));
      final collapsedHeight = tester.getSize(card).height;

      await tester.tap(find.byKey(const ValueKey('garden-evidence-see-more')));
      await tester.pumpAndSettle();

      final expandedHeight = tester.getSize(card).height;
      // On this 932px surface the 78%-of-usable-height cap is about 690px.
      // Two short evidence cards should grow naturally, not fill that space.
      expect(expandedHeight, greaterThan(collapsedHeight));
      expect(expandedHeight, lessThan(650));
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byKey(const ValueKey('garden-skill-evidence-scroll')),
                matching: find.byType(Scrollable),
              ),
            )
            .position
            .maxScrollExtent,
        0,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('garden-sheet-close'))).bottom,
        lessThanOrEqualTo(932),
      );
    },
  );

  testWidgets('strand chip text is vertically centered and left aligned', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    await _openSkillSheet(tester, _skill(strand: Strand.flu));

    final chip = find.byKey(const ValueKey('garden-strand-chip-flu'));
    final label = find.text('Fluency');
    final chipRect = tester.getRect(chip);
    final labelRect = tester.getRect(label);

    expect(labelRect.left - chipRect.left, closeTo(8, 0.5));
    expect(labelRect.center.dy, closeTo(chipRect.center.dy, 0.5));
  });

  testWidgets(
    'expanded evidence scrolls inside a bounded skill sheet on short phones',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 600));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      final skill = _skill(
        status: SkillStatus.owned,
        sightings: 3,
        evidence: List.generate(
          5,
          (index) => _evidence(
            'This is a deliberately long evidence example number $index that '
            'takes several lines so the expanded evidence list must scroll.',
            ageDays: index + 1,
          ),
        ),
      );

      await _openSkillSheet(tester, skill);
      await tester.ensureVisible(
        find.byKey(const ValueKey('garden-evidence-see-more')),
      );
      await tester.tap(find.byKey(const ValueKey('garden-evidence-see-more')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final close = find.byKey(const ValueKey('garden-sheet-close'));
      expect(tester.getRect(close).bottom, lessThanOrEqualTo(600));

      final evidenceScroll = find.descendant(
        of: find.byKey(const ValueKey('garden-skill-evidence-scroll')),
        matching: find.byType(Scrollable),
      );
      final scrollState = tester.state<ScrollableState>(evidenceScroll);
      expect(scrollState.position.maxScrollExtent, greaterThan(0));

      await tester.drag(evidenceScroll, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(scrollState.position.pixels, greaterThan(0));
    },
  );

  testWidgets(
    'previous-garden skill sheet with evidence still shows You used this',
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

      expect(find.text('You used this'), findsOneWidget);
      expect(find.text('My friend is tall and happy.'), findsOneWidget);
      expect(
        find.text(
          'This plant grows when you use this skill in your conversations',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'previous-garden skill sheet without evidence explains it was ready from the start',
    (tester) async {
      final skill = _skill(
        strand: Strand.voc,
        status: SkillStatus.owned,
        sightings: 3,
        displayText: 'Colours and numbers up to ten',
      );
      final step = _step(displayName: 'Naming the world', skills: [skill]);

      await _openSkillSheet(tester, skill, step: step, isPreviousGarden: true);

      // Skill name, strand tag and the stepper remain.
      expect(find.text('Colours and numbers up to ten'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('garden-strand-chip-voc')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('garden-skill-stepper')),
        findsOneWidget,
      );

      // The placement explanation replaces the empty-state block; it has no
      // evidence heading or inherited growth-completion badges.
      expect(find.text('Ready from the start'), findsOneWidget);
      expect(
        find.text(
          'You started at a higher level, so this skill is already bloomed.',
        ),
        findsOneWidget,
      );
      expect(
        tester
                .getRect(find.byKey(const ValueKey('garden-ready-from-start')))
                .top -
            tester
                .getRect(find.byKey(const ValueKey('garden-skill-stepper')))
                .bottom,
        closeTo(24, 0.5),
      );
      expect(
        find.text(
          'This plant grows when you use this skill in your conversations',
        ),
        findsNothing,
      );
      expect(find.text('You used this'), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    },
  );

  testWidgets(
    'current-garden skill sheet without evidence keeps the grow prompt',
    (tester) async {
      final skill = _skill(
        strand: Strand.voc,
        sightings: 0,
        displayText: 'Colours and numbers up to ten',
      );

      await _openSkillSheet(tester, skill);

      expect(
        find.text(
          'This plant grows when you use this skill in your conversations',
        ),
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

    // The board no longer carries the unit name; the skill copy still shows.
    expect(find.text('Refining past stories'), findsNothing);
    expect(find.text('Talk about what you used to do'), findsOneWidget);
    expect(find.text('Canonical framework skill statement'), findsNothing);
    expect(
      find.text('Talking about the past with more precision'),
      findsNothing,
    );
  });

  testWidgets('unit sheet shows every skill without a Show more control', (
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

    expect(find.text('Skill 0'), findsOneWidget);
    expect(find.text('Skill 1'), findsOneWidget);
    expect(find.text('Skill 2'), findsOneWidget);
    expect(find.text('Skill 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('garden-unit-show-more')), findsNothing);
    final fourSkillHeight = tester
        .getSize(find.byKey(const ValueKey('garden-sheet-card')))
        .height;

    await tester.pumpWidget(const SizedBox.shrink());
    await _openUnitSheet(tester, _step(skills: step.skills.take(2).toList()));

    expect(
      tester.getSize(find.byKey(const ValueKey('garden-sheet-card'))).height,
      lessThan(fourSkillHeight),
    );
  });

  testWidgets('unit sheet renders the revised heading and refreshed skill rows', (
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

    // The board no longer carries the unit name; it now heads the sheet body.
    expect(find.text('Keeping the thread'), findsOneWidget);
    expect(
      find.text(
        'Build up to a full minute of connected speech — linking ideas clearly, without losing the thread.',
      ),
      findsNothing,
    );
    final heading = tester.widget<Text>(
      find.byKey(const ValueKey('garden-unit-sheet-heading')),
    );
    expect(heading.data, "When this garden blooms, you'll be able to");
    expect(heading.style?.fontSize, 16);
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
      tester.getSize(
        find.byKey(const ValueKey('garden-unit-skill-icon-U1-VOC-01')),
      ),
      const Size(48, 48),
    );
  });

  testWidgets('shared sheet board is a fixed, empty, centered plank', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    final step = _step(displayName: 'First Words');

    await _openUnitSheet(tester, step);

    final board = find.byKey(const ValueKey('garden-sheet-board'));
    final card = find.byKey(const ValueKey('garden-sheet-card'));
    final leftNail = find.byKey(const ValueKey('garden-sheet-left-nail'));
    final rightNail = find.byKey(const ValueKey('garden-sheet-right-nail'));

    // 70% of the card's width, centered over the card, no title.
    final expectedBoardWidth = tester.getSize(card).width * 0.7;
    expect(tester.getSize(board).height, 40);
    expect(tester.getSize(board).width, closeTo(expectedBoardWidth, 0.5));
    expect(
      tester.getCenter(board).dx,
      closeTo(tester.getCenter(card).dx, 0.01),
    );
    expect(
      find.byKey(const ValueKey('garden-sheet-board-title')),
      findsNothing,
    );

    // Nails stay pinned at each end regardless of the (now-absent) title.
    final boardRect = tester.getRect(board);
    final leftNailRect = tester.getRect(leftNail);
    final rightNailRect = tester.getRect(rightNail);
    expect(leftNailRect.left - boardRect.left, closeTo(14, 0.01));
    expect(boardRect.right - rightNailRect.right, closeTo(14, 0.01));

    // A much longer unit name does not change the board's proportional width.
    await tester.pumpWidget(const SizedBox.shrink());
    final longStep = _step(
      displayName: 'A deliberately long garden unit title that used to wrap',
    );
    await _openUnitSheet(tester, longStep);
    expect(tester.getSize(board).height, 40);
    expect(tester.getSize(board).width, closeTo(expectedBoardWidth, 0.5));

    // Same board on the skill sheet.
    await tester.pumpWidget(const SizedBox.shrink());
    await _openSkillSheet(tester, step.skills.single, step: step);
    expect(tester.getSize(board).height, 40);
    expect(tester.getSize(board).width, closeTo(expectedBoardWidth, 0.5));
  });

  testWidgets('skill sheet has a round close button that dismisses it', (
    tester,
  ) async {
    await _setPhoneSurface(tester);
    await _openSkillSheet(tester, _skill());

    final close = find.byKey(const ValueKey('garden-sheet-close'));
    expect(close, findsOneWidget);
    expect(tester.getSize(close), const Size(48, 48));

    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('garden-sheet-card')), findsNothing);
  });
}
