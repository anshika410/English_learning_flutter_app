/// Bundled garden icons keyed to the rephrased curriculum framework.
///
/// A garden level represents the transition that starts at that level: A0 is
/// the A0 → A1 path, A1 is A1 → A2, and so on.
enum UnitIconVariant { colored, stone }

class CurriculumIcons {
  const CurriculumIcons._();

  static const Map<String, String> _transitionByLevel = {
    'A0': 'a0-a1',
    'A1': 'a1-a2',
    'A2': 'a2-b1',
    'B1': 'b1-b2',
    'B2': 'b2-c1',
    'C1': 'c1-c2',
  };

  // The icon files are ordered by the numbered prefixes supplied with each
  // curriculum transition. Skill order is VOC, GRA, then FLU within a unit.
  static const Map<String, List<String>> _skillFiles = {
    'a0-a1': [
      '01-rainbow.svg',
      '02-paw.svg',
      '03-bag-tag.svg',
      '04-pointing-hand.svg',
      '05-person.svg',
      '06-happy-face.svg',
      '07-backpack.svg',
      '08-wave.svg',
      '09-star.svg',
      '10-heart.svg',
      '11-plus.svg',
      '12-speech-bubble.svg',
      '13-pin.svg',
      '14-medal.svg',
      '15-box-position.svg',
      '16-raised-hands.svg',
      '17-running.svg',
      '18-question.svg',
      '19-chat-turns.svg',
      '20-sparkle.svg',
    ],
    'a1-a2': [
      '01-two-faces.svg',
      '02-now-clock.svg',
      '03-picture-frame.svg',
      '04-calendar-back.svg',
      '05-sneaker.svg',
      '06-swap-arrows.svg',
      '07-story-book.svg',
      '08-thought-heart.svg',
      '09-link-rings.svg',
      '10-balance-scale.svg',
      '11-bubble-bulb.svg',
      '12-repeat-arrows.svg',
      '13-sunrise-forward.svg',
      '14-target-dart.svg',
      '15-calendar-star.svg',
      '16-steps-123.svg',
      '17-tense-clock.svg',
      '18-bubbles-loop.svg',
      '19-strong-arm.svg',
    ],
    'a2-b1': [
      '01-palette.svg',
      '02-idiom-bubble.svg',
      '03-bridge.svg',
      '04-two-ways.svg',
      '05-puzzle.svg',
      '06-ringing-phone.svg',
      '07-old-photo.svg',
      '08-then-now-path.svg',
      '09-reporting-head.svg',
      '10-dominoes.svg',
      '11-modal-gauge.svg',
      '12-opinion-stack.svg',
      '13-linked-nodes.svg',
      '14-detail-lens.svg',
      '15-one-minute.svg',
      '16-organised-list.svg',
      '17-two-hats.svg',
      '18-gears.svg',
      '19-topic-switch.svg',
      '20-join-in.svg',
    ],
    'b1-b2': [
      '01-gem.svg',
      '02-handshake.svg',
      '03-crystal-ball.svg',
      '04-untangle.svg',
      '05-umbrella.svg',
      '06-rewind-branch.svg',
      '07-relay-quote.svg',
      '08-needle-thread.svg',
      '09-marker-flags.svg',
      '10-voice-toggle.svg',
      '11-microphone.svg',
      '12-winding-road.svg',
      '13-gavel.svg',
      '14-chain.svg',
      '15-spotlight.svg',
      '16-respectful-debate.svg',
      '17-register-sliders.svg',
      '18-medal-check.svg',
      '19-flying-bird.svg',
      '20-heart-key.svg',
    ],
    'b2-c1': [
      '01-grad-cap.svg',
      '02-abstract-shapes.svg',
      '03-inversion-flip.svg',
      '04-shade-fan.svg',
      '05-compress.svg',
      '06-modal-clock.svg',
      '07-syntax-tree.svg',
      '08-clear-glasses.svg',
      '09-train-link.svg',
      '10-back-reference.svg',
      '11-conductor.svg',
      '12-briefcase.svg',
      '13-venn-three.svg',
      '14-highlighter.svg',
      '15-register-dial.svg',
      '16-wink-face.svg',
      '17-shield-check.svg',
      '18-summit-flag.svg',
      '19-sailboat.svg',
    ],
    'c1-c2': [
      '01-pen-nib.svg',
      '02-measure-fit.svg',
      '03-column.svg',
      '04-open-door.svg',
      '05-butterfly.svg',
      '06-music-notes.svg',
      '07-laurel.svg',
      '08-paper-plane.svg',
      '09-book-stack.svg',
      '10-layered-bubbles.svg',
      '11-equal-bubbles.svg',
      '12-round-table.svg',
      '13-instinct-heart.svg',
      '14-clear-pane.svg',
      '15-home-bubble.svg',
      '16-owl.svg',
      '17-chess-king.svg',
      '18-four-point-star.svg',
      '19-golden-bridge.svg',
    ],
  };

  static const Map<String, List<String>> _unitFiles = {
    'a0-a1': [
      'u1-apple-tag.svg',
      'u2-hello-badge.svg',
      'u3-like-dislike.svg',
      'u4-can-do-bubble.svg',
      'u5-binoculars.svg',
    ],
    'a1-a2': [
      'u1-globe.svg',
      'u2-past-clock.svg',
      'u3-lightbulb.svg',
      'u4-signpost.svg',
      'u5-two-bubbles.svg',
    ],
    'a2-b1': [
      'u1-magnifier.svg',
      'u2-hourglass.svg',
      'u3-megaphone.svg',
      'u4-thread-spool.svg',
      'u5-compass.svg',
    ],
    'b1-b2': [
      'u1-sharp-pencil.svg',
      'u2-knot.svg',
      'u3-ribbon.svg',
      'u4-podium.svg',
      'u5-fountain.svg',
    ],
    'b2-c1': [
      'u1-quill.svg',
      'u2-infinity.svg',
      'u3-scroll.svg',
      'u4-masks.svg',
      'u5-bow-arrow.svg',
    ],
    'c1-c2': [
      'u1-brain.svg',
      'u2-paintbrush.svg',
      'u3-orbit-star.svg',
      'u4-fingerprint.svg',
      'u5-crown.svg',
    ],
  };

  // Counts are [Vocabulary, Grammar, Fluency] for each of the five units.
  static const Map<String, List<List<int>>> _skillCounts = {
    'a0-a1': [
      [2, 1, 1],
      [1, 2, 1],
      [1, 2, 1],
      [1, 2, 1],
      [0, 2, 2],
    ],
    'a1-a2': [
      [1, 1, 1],
      [1, 2, 1],
      [1, 2, 1],
      [2, 1, 1],
      [1, 1, 2],
    ],
    'a2-b1': [
      [2, 1, 1],
      [1, 2, 1],
      [1, 2, 1],
      [1, 1, 2],
      [1, 1, 2],
    ],
    'b1-b2': [
      [2, 1, 1],
      [1, 2, 1],
      [1, 1, 2],
      [1, 2, 1],
      [1, 1, 2],
    ],
    'b2-c1': [
      [2, 1, 1],
      [1, 2, 1],
      [1, 1, 2],
      [1, 1, 1],
      [1, 1, 2],
    ],
    'c1-c2': [
      [2, 1, 1],
      [1, 2, 1],
      [1, 1, 2],
      [1, 1, 1],
      [1, 1, 2],
    ],
  };

  static String? transitionForLevel(String level) =>
      _transitionByLevel[level.trim().toUpperCase()];

  static String? unitAsset(
    String level,
    int unit, {
    UnitIconVariant variant = UnitIconVariant.colored,
  }) {
    final transition = transitionForLevel(level);
    final files = transition == null ? null : _unitFiles[transition];
    if (files == null || unit < 1 || unit > files.length) return null;
    final name = files[unit - 1];
    final resolvedName = variant == UnitIconVariant.stone
        ? name.replaceFirst('.svg', '-stone.svg')
        : name;
    return 'assets/unit-icons/$transition/$resolvedName';
  }

  static String? skillAsset(String level, int unit, String skillId) {
    final transition = transitionForLevel(level);
    final counts = transition == null ? null : _skillCounts[transition];
    final files = transition == null ? null : _skillFiles[transition];
    final match = RegExp(
      r'^U(\d+)-(VOC|GRA|FLU)-(\d+)$',
    ).firstMatch(skillId.trim().toUpperCase());
    if (counts == null || files == null || match == null) return null;

    final idUnit = int.parse(match.group(1)!);
    final strand = switch (match.group(2)!) {
      'VOC' => 0,
      'GRA' => 1,
      _ => 2,
    };
    final occurrence = int.parse(match.group(3)!);
    if (unit != idUnit || unit < 1 || unit > counts.length) return null;
    if (occurrence < 1 || occurrence > counts[unit - 1][strand]) return null;

    var index = 0;
    for (var i = 0; i < unit - 1; i++) {
      index += counts[i][0] + counts[i][1] + counts[i][2];
    }
    for (var i = 0; i < strand; i++) {
      index += counts[unit - 1][i];
    }
    index += occurrence - 1;
    return 'assets/skill-icons/$transition/${files[index]}';
  }

  static List<String> skillIdsForUnit(String level, int unit) {
    final transition = transitionForLevel(level);
    final counts = transition == null ? null : _skillCounts[transition];
    if (counts == null || unit < 1 || unit > counts.length) return const [];
    const strands = ['VOC', 'GRA', 'FLU'];
    final ids = <String>[];
    for (var strand = 0; strand < strands.length; strand++) {
      for (var i = 1; i <= counts[unit - 1][strand]; i++) {
        ids.add('U$unit-${strands[strand]}-${i.toString().padLeft(2, '0')}');
      }
    }
    return ids;
  }
}
