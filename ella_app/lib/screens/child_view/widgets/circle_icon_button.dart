// Circular header shortcut (Home / Placement Home top-right): a 64×64 filled
// circle with a 3px ring around a glyph, plus an optional caption below
// ("Profile" / "Garden" in the Figma placement flow).

import 'package:flutter/material.dart';

import '../../../core/text_styles.dart';
import '../../../services/audio_service.dart';

class EllaCircleIconButton extends StatelessWidget {
  final Widget glyph;
  final Color fill;
  final Color ring;
  final VoidCallback? onTap;

  /// Diameter of the circular badge. Defaults to the 64px placement-flow size.
  final double diameter;

  /// Caption under the circle; omitted when null.
  final String? label;
  final Color? labelColor;

  /// Base style for the caption; defaults to [EllaTextStyles.caption]. Callers
  /// pass a larger style (e.g. [EllaTextStyles.buttonSmall] on the placement
  /// intro) to meet the ≥14px label spec. [labelColor] still tints it.
  final TextStyle? labelStyle;

  /// When true, the caption renders as a rounded pill "chip" (home screen)
  /// instead of bare text. [chipFill] / [chipBorder] tint the pill; the text
  /// still uses [labelColor].
  final bool labelAsChip;
  final Color? chipFill;
  final Color? chipBorder;

  const EllaCircleIconButton({
    super.key,
    required this.glyph,
    required this.fill,
    required this.ring,
    required this.onTap,
    this.diameter = 64,
    this.label,
    this.labelColor,
    this.labelStyle,
    this.labelAsChip = false,
    this.chipFill,
    this.chipBorder,
  });

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 3),
      ),
      child: glyph,
    );

    if (label == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: withTapClick(onTap),
        child: circle,
      );
    }

    final captionStyle = (labelStyle ?? EllaTextStyles.caption).copyWith(
      color: labelColor,
    );
    final Widget caption = labelAsChip
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: chipFill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: chipBorder ?? ring, width: 1.5),
            ),
            child: Text(label!, style: captionStyle),
          )
        : Text(label!, style: captionStyle);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          SizedBox(height: labelAsChip ? 8 : 4),
          caption,
        ],
      ),
    );
  }
}
