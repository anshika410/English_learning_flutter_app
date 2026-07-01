// Warm "lamp-lit room" backdrop shared by the Home and Session screens.
// Two-tone brown gradient + the hanging lamp SVG (which already contains its
// cord, shade, bulb and glow) anchored top-centre. Content is layered on top.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme_colors.dart';

class RoomBackground extends StatelessWidget {
  final Widget child;

  /// Vertical position (0–1 of the backdrop height) of the crisp line between
  /// the tan upper wall and the brown lower floor. Home pushes this down so the
  /// greeting bubble straddles the line; Session keeps the default.
  final double splitAt;

  const RoomBackground({super.key, required this.child, this.splitAt = 0.66});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Two distinct, visually separated bands (Figma): a flat tan upper wall
        // and a flat brown lower floor split by a crisp horizontal line (the
        // tiny gap between the two stops just anti-aliases the edge).
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            EllaColors.roomWallTop,
            EllaColors.roomWallTop,
            EllaColors.roomWallBottom,
            EllaColors.roomWallBottom,
          ],
          stops: [0.0, splitAt, splitAt + 0.005, 1.0],
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
