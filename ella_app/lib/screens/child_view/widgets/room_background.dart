// Warm "lamp-lit room" backdrop shared by the Home and Session screens.
// Two-tone brown gradient + the hanging lamp SVG (which already contains its
// cord, shade, bulb and glow) anchored top-centre. Content is layered on top.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme_colors.dart';

class RoomBackground extends StatelessWidget {
  final Widget child;

  const RoomBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [EllaColors.roomWallTop, EllaColors.roomWallBottom],
          stops: [0.0, 0.72],
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
