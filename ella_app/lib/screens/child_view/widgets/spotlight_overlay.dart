// Radial vignette: transparent over the highlighted element, easing to a
// translucent dark-green scrim at the edges. Shared by the onboarding first
// sprout, the placement bloom, and the garden's first-time welcome. Modelled on
// the sun RadialGradient in garden_sky_background.dart.

import 'dart:ui';

import 'package:flutter/material.dart';

class SpotlightOverlay extends StatelessWidget {
  /// Where the bright (transparent) hole sits, in alignment coordinates.
  final Alignment center;
  final Offset? pixelCenter;
  final double radius;
  final bool figmaStyle;

  const SpotlightOverlay({
    super.key,
    this.center = const Alignment(0, 0.25),
    this.pixelCenter,
    this.radius = 0.85,
    this.figmaStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedCenter = pixelCenter == null
            ? center
            : Alignment(
                (pixelCenter!.dx / constraints.maxWidth) * 2 - 1,
                (pixelCenter!.dy / constraints.maxHeight) * 2 - 1,
              );
        final colors = figmaStyle
            ? const [Color(0x002B362F), Color(0x002B362F), Color(0x522B362F)]
            : const [
                Color(0x00185E35),
                Color(0x00185E35),
                Color(0x66123B23),
                Color(0x99102F1D),
              ];
        final stops = figmaStyle
            ? const [0.0, 0.59615, 1.0]
            : const [0.0, 0.35, 0.75, 1.0];

        return ClipRect(
          child: BackdropFilter(
            filter: figmaStyle
                ? ImageFilter.blur(sigmaX: 6, sigmaY: 6)
                : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: resolvedCenter,
                  radius: radius,
                  colors: colors,
                  stops: stops,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
