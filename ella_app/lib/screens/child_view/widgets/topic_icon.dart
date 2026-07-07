// Topic icon — renders the per-topic glyph for a next_topics suggestion.
//
// The memory API sends an `icon` id (e.g. "a1-04-food-i-like"); the matching
// SVGs are bundled under assets/topic-icons/ (downloaded from the backend's
// hosted set at /assets/topic-icons/<id>.svg). Unknown/empty ids fall back to
// the generic chat-bubble glyph so a new server icon never renders a broken
// asset error.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Every icon id bundled in assets/topic-icons/ — mirrors the backend's
/// TOPIC_ICON_MAP values (backend/app/routers/users.py). Keep in sync when new
/// icons are added server-side.
const Set<String> kBundledTopicIcons = {
  'a1-01-my-name',
  'a1-02-my-family',
  'a1-03-my-school',
  'a1-04-food-i-like',
  'a1-05-my-daily-routine',
  'a1-06-likes-dontlikes',
  'a1-07-animals',
  'a1-08-colours-numbers-shapes',
  'a1-09-my-home',
  'a1-10-sports-and-games',
  'a1-11-festivals',
  'a2-01-hobbies-free-time',
  'a2-02-my-friends',
  'a2-03-typical-week',
  'a2-04-shopping-and-markets',
  'a2-05-food-and-restaurants',
  'a2-06-my-city-or-town',
  'a2-07-weather-and-seasons',
  'a2-08-transport-and-travel',
  'a2-09-a-trip-or-holiday',
  'a2-10-films-and-tv-shows',
  'a2-11-celebrations',
  'a2-12-school-subjects',
  'b1-01-ambitions-future-plans',
  'b1-02-personality-and-values',
  'b1-03-education-in-india',
  'b1-04-social-media-technology',
  'b1-05-city-vs-village',
  'b1-06-festivals-and-traditions',
  'b1-07-environment-pollution',
  'b1-08-health-and-lifestyle',
  'b1-09-indian-cinema-music',
  'b1-10-friendship-and-trust',
  'b1-11-news-current-events',
  'b1-12-cricket-and-sport',
  'b2-01-culture-and-identity',
  'b2-02-gender-equality',
  'b2-03-education-and-success',
  'b2-04-ai-future-of-work',
  'b2-05-social-media-mental-health',
  'b2-06-climate-change-india',
  'b2-07-migration-and-opportunity',
  'b2-08-tradition-vs-modernity',
  'b2-09-fake-news-media-literacy',
  'b2-10-entrepreneurship-startups',
  'b2-11-indian-literature-storytelling',
  'b2-12-privilege-and-opportunity',
};

class TopicIcon extends StatelessWidget {
  /// The API's icon id (TopicChoice.icon). May be empty or unmapped.
  final String icon;
  final double size;

  /// Tint for the fallback chat-bubble glyph only — the SVG icons keep their
  /// own colours.
  final Color fallbackColor;

  const TopicIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    if (kBundledTopicIcons.contains(icon)) {
      return SvgPicture.asset(
        'assets/topic-icons/$icon.svg',
        width: size,
        height: size,
      );
    }
    return Icon(Icons.chat_bubble_rounded, size: size, color: fallbackColor);
  }
}
