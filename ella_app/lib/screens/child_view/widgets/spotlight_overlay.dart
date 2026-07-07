// Radial vignette: transparent over the highlighted element, easing to a
// translucent dark-green scrim at the edges. Shared by the onboarding first
// sprout, the placement bloom, and the garden's first-time welcome. Modelled on
// the sun RadialGradient in garden_sky_background.dart.

import 'package:flutter/material.dart';

class SpotlightOverlay extends StatelessWidget {
  /// Where the bright (transparent) hole sits, in alignment coordinates.
  final Alignment center;
  final double radius;

  const SpotlightOverlay({
    super.key,
    this.center = const Alignment(0, 0.25),
    this.radius = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: const [
            Color(0x00185E35),
            Color(0x00185E35),
            Color(0x7A123B23),
            Color(0xB3102F1D),
          ],
          stops: const [0.0, 0.35, 0.75, 1.0],
        ),
      ),
    );
  }
}
