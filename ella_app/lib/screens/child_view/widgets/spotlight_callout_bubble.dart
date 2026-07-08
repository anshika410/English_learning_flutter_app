// Shared "first plant" spotlight callout bubble (Figma node 598:17012). One
// widget for both the placement reveal and the garden first-time welcome so the
// two read identically — only the copy differs. Cream card with a squared
// top-left tail + blue info border; the title sits on one line with the sprout
// icon hugging it (never given its own column), and the body wraps naturally
// below. Both lines are deep green.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/ella_smooth_shape.dart';
import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../chat_bubble.dart';

const String _kSproutIcon = 'assets/homescreen/new/Plant.svg';

class SpotlightCalloutBubble extends StatelessWidget {
  final String title;
  final String body;
  final int highlightStart;
  final int highlightEnd;

  const SpotlightCalloutBubble({
    super.key,
    required this.title,
    required this.body,
    this.highlightStart = -1,
    this.highlightEnd = -1,
  });

  @override
  Widget build(BuildContext context) {
    final green = EllaTextStyles.bodySemiboldLarge.copyWith(
      color: EllaColors.greenDeep,
    );

    final titleHighlightStart = highlightStart < title.length ? highlightStart : -1;
    final titleHighlightEnd = highlightStart < title.length ? highlightEnd : -1;

    final titleLength = title.length + 1; // account for newline
    final bodyHighlightStart = highlightStart >= titleLength ? highlightStart - titleLength : -1;
    final bodyHighlightEnd = highlightStart >= titleLength ? highlightEnd - titleLength : -1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        side: const BorderSide(color: EllaColors.info, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FittedBox keeps the title on one line (scaling down only if a
              // narrow screen forces it); the sprout then sits right beside it.
              Flexible(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: TypewriterText(
                    text: title,
                    style: green,
                    highlightStart: titleHighlightStart,
                    highlightEnd: titleHighlightEnd,
                    animate: false,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(_kSproutIcon, width: 32, height: 32),
            ],
          ),
          const SizedBox(height: 8),
          TypewriterText(
            text: body,
            style: green,
            highlightStart: bodyHighlightStart,
            highlightEnd: bodyHighlightEnd,
            animate: false,
          ),
        ],
      ),
    );
  }
}
