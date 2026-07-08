import 'package:flutter/material.dart';

/// Figma-style smoothed rounded rectangle used for Ella's expressive surfaces.
///
/// Keep true circles as circles; this helper is for cards, bubbles, and pill
/// CTAs that use rounded rectangle geometry with corner smoothing.
ShapeDecoration ellaSmoothDecoration({
  required Color color,
  required BorderRadiusGeometry borderRadius,
  BorderSide side = BorderSide.none,
  List<BoxShadow>? shadows,
}) {
  return ShapeDecoration(
    color: color,
    shadows: shadows,
    shape: RoundedSuperellipseBorder(side: side, borderRadius: borderRadius),
  );
}
