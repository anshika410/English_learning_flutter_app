// Radial vignette: transparent over the highlighted element, easing to a
// translucent dark-green scrim at the edges. Shared by the onboarding first
// sprout, the placement bloom, and the garden's first-time welcome. Modelled on
// the soft radial lighting used throughout the botanical scene.

import 'dart:ui';

import 'package:flutter/material.dart';

enum SpotlightIntensity { normal, strong }

class SpotlightOverlay extends StatelessWidget {
  /// Where the bright (transparent) hole sits, in alignment coordinates.
  final Alignment center;
  final Offset? pixelCenter;
  final double radius;
  final bool figmaStyle;
  final SpotlightIntensity intensity;

  const SpotlightOverlay({
    super.key,
    this.center = const Alignment(0, 0.25),
    this.pixelCenter,
    this.radius = 0.85,
    this.figmaStyle = false,
    this.intensity = SpotlightIntensity.normal,
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
            ? intensity == SpotlightIntensity.strong
                  ? const [
                      Color(0x002B362F),
                      Color(0x002B362F),
                      Color(0x8A162018),
                    ]
                  : const [
                      Color(0x002B362F),
                      Color(0x002B362F),
                      Color(0x522B362F),
                    ]
            : const [
                Color(0x00185E35),
                Color(0x00185E35),
                Color(0x7A123B23),
                Color(0xB3102F1D),
              ];
        final stops = figmaStyle
            ? intensity == SpotlightIntensity.strong
                  ? const [0.0, 0.36, 1.0]
                  : const [0.0, 0.59615, 1.0]
            : const [0.0, 0.45, 0.8, 1.0];

        // The blur is masked to the dimmed ring only: a RadialGradient that is
        // transparent over the bright hole and opaque toward the edges, used as
        // a dstIn mask on the BackdropFilter. This keeps the spotlit element
        // crystal-clear while the surrounding scrim is both blurred and dimmed.
        final blurSigma = figmaStyle
            ? intensity == SpotlightIntensity.strong
                  ? 2.0
                  : 6.0
            : 5.0;
        // Match the mask's transparent zone to the darkening gradient's inner
        // (transparent) stop so the clear region lines up with the bright hole.
        final innerClearStop = stops.length >= 2 ? stops[1] : 0.5;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (blurSigma > 0)
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => RadialGradient(
                    center: resolvedCenter,
                    radius: radius,
                    colors: const [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xFF000000),
                    ],
                    stops: [0.0, innerClearStop, 1.0],
                  ).createShader(rect),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: resolvedCenter,
                    radius: radius,
                    colors: colors,
                    stops: stops,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
