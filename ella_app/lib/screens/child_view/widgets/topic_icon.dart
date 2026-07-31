// Topic icon — renders the per-topic glyph for a next_topics suggestion.
//
// The memory API sends an `icon` id (e.g. "a1-04-food-i-like"); the matching
// SVGs are bundled under assets/topic-icons/ (downloaded from the backend's
// hosted set at /assets/topic-icons/<id>.svg). Unknown/empty ids fall back to
// the generic chat-bubble glyph so a new server icon never renders a broken
// asset error.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/text_styles.dart';

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
  'c1-01-what-does-it-mean-indian',
  'c1-02-moral-dilemmas',
  'c1-03-ethics-of-ai',
  'c1-04-caste-class-social-mobility',
  'c1-05-sustainability-lifestyle',
  'c1-06-mental-health-stigma',
  'c1-07-democracy-young-people',
  'c1-08-english-in-india',
  'c1-09-art-music-society',
  'c1-10-success-happiness-meaning',
  'c1-11-indias-role-in-world',
  'c1-12-science-superstition-belief',
  'c2-01-language-shape-thought',
  'c2-02-justice-fairness',
  'c2-03-how-do-we-know',
  'c2-04-what-makes-us-human',
  'c2-05-power-privilege-storytelling',
  'c2-06-future-of-democracy',
  'c2-07-ethics-genetic-technology',
  'c2-08-what-is-art-for',
  'c2-09-self-fixed-or-fluid',
  'c2-10-limits-of-globalisation',
  'c2-11-freedom-how-much',
  'c2-12-what-do-we-owe-future',
};

/// The measured presentation for a topic label at a particular card width.
class TopicLabelLayout {
  final double fontSize;
  final double height;
  final int maxLines;
  final bool didOverflow;

  const TopicLabelLayout({
    required this.fontSize,
    required this.height,
    required this.maxLines,
    required this.didOverflow,
  });
}

const double kTopicIconSize = 56;
const double kTopicIconLabelGap = 4;
const double kTopicCardVerticalPadding = 12;
const double kTopicCardMaximumHorizontalPadding = 12;
const double kTopicCardMinimumHorizontalPadding = 8;
const double kTopicLabelFontSize = 12;
const double kTopicLabelMaximumFontSize = 14;

TextStyle topicLabelStyle(
  Color color, {
  double fontSize = kTopicLabelFontSize,
}) => EllaTextStyles.bodySmall.copyWith(
  fontSize: fontSize,
  fontWeight: FontWeight.w700,
  color: color,
  height: 1.2,
);

/// Respects system scaling until the rendered topic label reaches 14px.
TextScaler topicLabelTextScaler(BuildContext context) =>
    MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: kTopicLabelMaximumFontSize / kTopicLabelFontSize);

/// Measures a label using the same typography used by [TopicCardLabel].
///
/// Every label uses the compact 12px topic-card size. Multi-word labels may
/// wrap to two lines, while a single word stays on one line.
TopicLabelLayout measureTopicLabel(
  BuildContext context, {
  required String text,
  required double maxWidth,
  bool allowWrap = true,
}) {
  const fontSize = kTopicLabelFontSize;
  final isSingleWord = !text.trim().contains(RegExp(r'\s'));
  final maxLines = !allowWrap || isSingleWord ? 1 : 2;
  final textDirection = Directionality.of(context);
  final textScaler = topicLabelTextScaler(context);

  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: topicLabelStyle(Colors.black, fontSize: fontSize),
    ),
    maxLines: maxLines,
    ellipsis: '…',
    textDirection: textDirection,
    textScaler: textScaler,
    textAlign: TextAlign.center,
  )..layout(maxWidth: maxWidth);

  return TopicLabelLayout(
    fontSize: fontSize,
    height: painter.height,
    maxLines: maxLines,
    didOverflow: painter.didExceedMaxLines,
  );
}

/// Chooses one horizontal inset for an entire row of equal-width topic cards.
///
/// Rows keep the preferred 12px inset whenever every label fits. On narrower
/// screens the inset steps down uniformly to 8px, avoiding per-card visual
/// jitter while giving long labels a little more room.
double responsiveTopicHorizontalPadding(
  BuildContext context, {
  required Iterable<String> labels,
  required double cardWidth,
  Iterable<String> singleLineLabels = const [],
}) {
  final oneLine = singleLineLabels.toSet();
  for (
    var padding = kTopicCardMaximumHorizontalPadding;
    padding >= kTopicCardMinimumHorizontalPadding;
    padding -= 0.5
  ) {
    final labelWidth = cardWidth - padding * 2;
    final allFit = labels.every(
      (label) => !measureTopicLabel(
        context,
        text: label,
        maxWidth: labelWidth,
        allowWrap: !oneLine.contains(label),
      ).didOverflow,
    );
    if (allFit) return padding;
  }
  return kTopicCardMinimumHorizontalPadding;
}

/// A topic label occupying a row-wide label slot. One-line cards in a mixed
/// row leave the unused part of the slot below their text.
class TopicCardLabel extends StatelessWidget {
  final String text;
  final Color color;
  final TopicLabelLayout layout;
  final double slotHeight;

  const TopicCardLabel({
    super.key,
    required this.text,
    required this.color,
    required this.layout,
    required this.slotHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: slotHeight,
      child: Align(
        alignment: Alignment.topCenter,
        child: Text(
          text,
          textScaler: topicLabelTextScaler(context),
          maxLines: layout.maxLines,
          softWrap: layout.maxLines > 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: topicLabelStyle(color, fontSize: layout.fontSize),
        ),
      ),
    );
  }
}

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
        fit: BoxFit.contain,
        alignment: Alignment.center,
      );
    }
    return Icon(Icons.chat_bubble_rounded, size: size, color: fallbackColor);
  }
}
