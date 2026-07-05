// Topic card shown on the home screen — mirrors GET /users/me/topics.
// This is the *presentation* topic (rich styling + copy from the server); it is
// distinct from the engine `Topic` in core/topic_data.dart, which only carries
// the fields the deterministic engine/judge/prompt code needs. `toEngineTopic`
// bridges a chosen card into that engine type so an API topic can start a
// session without touching the engine.

import '../core/topic_data.dart';

class HomeTopic {
  final String id;
  final String name;
  final String theme;
  final String description;
  final String icon; // emoji glyph, e.g. "👤" — render as Text, not IconData
  final String color; // hex, e.g. "#E0EDFF"
  final String highlightColor; // rgba/hex
  final String panelBg; // CSS gradient string (best-effort on native)
  final List<String> vocabSeeds;
  final List<String> structureTargets;
  final List<String> starters;

  const HomeTopic({
    required this.id,
    required this.name,
    this.theme = '',
    this.description = '',
    this.icon = '',
    this.color = '',
    this.highlightColor = '',
    this.panelBg = '',
    this.vocabSeeds = const [],
    this.structureTargets = const [],
    this.starters = const [],
  });

  factory HomeTopic.fromJson(Map<String, dynamic> j) => HomeTopic(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    theme: (j['theme'] ?? '').toString(),
    description: (j['description'] ?? '').toString(),
    icon: (j['icon'] ?? '').toString(),
    color: (j['color'] ?? '').toString(),
    highlightColor: (j['highlight_color'] ?? '').toString(),
    panelBg: (j['panel_bg'] ?? '').toString(),
    vocabSeeds: _stringList(j['vocab_seeds']),
    structureTargets: _stringList(j['structure_targets']),
    starters: _stringList(j['starters']),
  );

  static List<String> _stringList(Object? value) => value is List
      ? [for (final v in value) v.toString()]
      : const [];

  /// Bridges this presentation card into the engine `Topic` so a tapped topic
  /// can flow through the existing session/judge/prompt code unchanged. The
  /// level isn't on the topics payload, so the caller passes the child's level.
  Topic toEngineTopic(String level) => Topic(
    level: level,
    theme: theme,
    topic: name,
    starters: starters.join(' / '),
  );
}
