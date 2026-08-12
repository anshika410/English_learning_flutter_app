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

  // The icon files are ordered to match how [skillAsset] packs each unit's
  // skills: VOC, then GRA, then FLU. For most units the numbered file prefixes
  // already follow that order. The one exception is a0-a1 Unit 2, whose files
  // were numbered in curriculum/display order (FLU, VOC, GRA, GRA); its four
  // entries are intentionally reordered below to the VOC/GRA/FLU packing so the
  // icons line up. Do not restore them to numeric prefix order.
  static const Map<String, List<String>> _skillFiles = {
    'a0-a1': [
      '01-colour-orb.svg',
      '02-number-bars.svg',
      '03-bag-tag.svg',
      '04-answer-bubbles.svg',
      // Unit 2 — reordered to VOC, GRA, GRA, FLU (see note above).
      '06-family-trio.svg', // U2-VOC-01 Name people in your family
      '08-wave.svg', // U2-GRA-01 Use I am, I'm not
      '07-backpack.svg', // U2-GRA-02 Say what you have
      '05-person.svg', // U2-FLU-01 Say your name and age
      '09-star.svg',
      '10-heart.svg',
      '11-plus.svg',
      '12-speech-bubble.svg',
      '13-action-place.svg',
      '14-medal.svg',
      '15-box-position.svg',
      '16-raised-hands.svg',
      '17-action-figure.svg',
      '18-question.svg',
      '19-chat-turns.svg',
      '20-ear-loop.svg',
    ],
    'a1-a2': [
      '01-two-faces.svg',
      '02-now-clock.svg',
      '03-picture-frame.svg',
      '04-detail-lens.svg',
      '05-sneaker.svg',
      '06-past-verb-clock.svg',
      '07-story-book.svg',
      '08-story-question.svg',
      '09-link-rings.svg',
      '10-balance-scale.svg',
      '11-bubble-bulb.svg',
      '12-repeat-arrows.svg',
      '13-clock-calendar.svg',
      '14-target-dart.svg',
      '15-calendar-star.svg',
      '16-steps-123.svg',
      '17-tense-clock.svg',
      '18-bubbles-loop.svg',
      '19-fork-paths.svg',
    ],
    'a2-b1': [
      '01-palette.svg',
      '02-idiom-bubble.svg',
      '03-bridge.svg',
      '04-two-ways.svg',
      '05-puzzle.svg',
      '06-ringing-phone.svg',
      '07-old-photo.svg',
      '08-story-arc.svg',
      '09-reporting-head.svg',
      '10-dominoes.svg',
      '11-modal-gauge.svg',
      '12-defend-shield-face.svg',
      '13-linked-nodes.svg',
      '14-detail-lens.svg',
      '15-one-minute.svg',
      '16-return-arrow.svg',
      '17-two-hats.svg',
      '18-gears.svg',
      '19-topic-switch.svg',
      '20-group-join.svg',
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
      '15-flag-stand.svg',
      '16-respectful-debate.svg',
      '17-register-sliders.svg',
      '18-medal-check.svg',
      '19-flying-bird.svg',
      '20-smiley-check.svg',
    ],
    'b2-c1': [
      '01-grad-cap.svg',
      '02-compare-abstract.svg',
      '03-emphasis-arrow.svg',
      '04-shade-fan.svg',
      '05-expand-box.svg',
      '06-modal-clock.svg',
      '07-syntax-tree.svg',
      '08-rephrase-bubble.svg',
      '09-train-link.svg',
      '10-back-reference.svg',
      '11-conductor.svg',
      '12-briefcase.svg',
      '13-audience-split.svg',
      '14-highlighter.svg',
      '15-register-dial.svg',
      '16-wink-face.svg',
      '17-shield-check.svg',
      '18-podium-star.svg',
      '19-compass-star.svg',
    ],
    'c1-c2': [
      '01-pen-nib.svg',
      '02-triangle-audience.svg',
      '03-column.svg',
      '04-idea-facets.svg',
      '05-quill-flourish.svg',
      '06-music-notes.svg',
      '07-laurel.svg',
      '08-paper-plane.svg',
      '09-book-lens.svg',
      '10-layered-bubbles.svg',
      '11-varied-voices.svg',
      '12-round-table.svg',
      '13-lightning-fast.svg',
      '14-grammar-stack.svg',
      '15-flow-fix.svg',
      '16-voice-bars.svg',
      '17-vocab-vault.svg',
      '18-grammar-arch.svg',
      '19-golden-bridge.svg',
      '20-four-paths.svg',
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
      [1, 1, 2]
    ],
    'a1-a2': [
      [1, 1, 2],
      [1, 1, 2],
      [1, 2, 1],
      [1, 1, 1],
      [1, 1, 2]
    ],
    'a2-b1': [
      [2, 1, 1],
      [1, 2, 1],
      [1, 2, 1],
      [1, 1, 2],
      [1, 1, 2]
    ],
    'b1-b2': [
      [2, 1, 1],
      [1, 2, 1],
      [1, 1, 2],
      [1, 1, 2],
      [1, 1, 2]
    ],
    'b2-c1': [
      [2, 1, 1],
      [1, 2, 1],
      [1, 1, 2],
      [1, 1, 1],
      [1, 1, 2]
    ],
    'c1-c2': [
      [2, 1, 1],
      [1, 2, 1],
      [1, 1, 2],
      [1, 1, 2],
      [1, 1, 2]
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
