// Greenhouse backdrop shared by the Home and Session screens (Botanical Berry).
// A calm sky→mint environment gradient + the hanging lamp SVG anchored
// top-centre. Content is layered on top.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme_colors.dart';

class RoomBackground extends StatelessWidget {
  final Widget child;

  /// Vertical position (0–1 of the backdrop height) where the sky settles into
  /// the mint-tinted lower air. Home pushes this down so the greeting bubble
  /// straddles it; Session keeps the default.
  final double splitAt;

  const RoomBackground({super.key, required this.child, this.splitAt = 0.66});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Greenhouse air: bright sky light up top easing into the mint-tinted
        // surface band, so the room reads as an airy glasshouse rather than a
        // warm lamp-lit den. splitAt controls where the sky gives way to mint.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            EllaColors.environmentLight,
            EllaColors.environmentMain,
            EllaColors.surfaceVariant,
          ],
          stops: [0.0, splitAt, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Hanging lamp, top-centre, hugging the top edge.
          Align(
            alignment: Alignment.topCenter,
            child: SvgPicture.asset(
              'assets/bottom_tab/ceiling-light.svg',
              width: 92,
              fit: BoxFit.fitWidth,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
