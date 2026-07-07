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

  /// Caption under the circle; omitted when null.
  final String? label;
  final Color? labelColor;

  /// Base style for the caption; defaults to [EllaTextStyles.caption]. Callers
  /// pass a larger style (e.g. [EllaTextStyles.buttonSmall] on the placement
  /// intro) to meet the ≥14px label spec. [labelColor] still tints it.
  final TextStyle? labelStyle;

  const EllaCircleIconButton({
    super.key,
    required this.glyph,
    required this.fill,
    required this.ring,
    required this.onTap,
    this.label,
    this.labelColor,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 3),
      ),
      child: glyph,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: label == null
          ? circle
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                circle,
                const SizedBox(height: 4),
                Text(
                  label!,
                  style: (labelStyle ?? EllaTextStyles.caption).copyWith(
                    color: labelColor,
                  ),
                ),
              ],
            ),
    );
  }
}
