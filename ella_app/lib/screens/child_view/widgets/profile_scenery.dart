// Background for the Profile screen — Figma "Profile" frame (node 515:8596):
// a soft cyan sky gradient with a low sun, two drifting clouds and two rolling
// green hills anchored to the bottom. No flowers/blooms (unlike the pre-auth
// [OnboardingScenery]). Content is layered on top via [child].
//
// Positions/sizes are expressed against the 430-wide Figma reference frame and
// scaled to the actual width so the scene holds its proportions on any device.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileScenery extends StatelessWidget {
  final Widget child;

  const ProfileScenery({super.key, required this.child});

  static const _refWidth = 430.0;
  static const _asset = 'assets/profile';

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Sky: light cyan easing down (Figma profile gradient).
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEAFDFF),
            Color(0xFFD9FAFF),
            Color(0xFFE7FBF6),
          ],
          stops: [0.0, 0.206, 0.374],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = constraints.maxWidth / _refWidth;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Back hill (full width), anchored to the bottom.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: constraints.maxWidth * 627.284 / _refWidth,
                child: SvgPicture.asset(
                  '$_asset/hill-back.svg',
                  fit: BoxFit.fill,
                ),
              ),
              // Front hill (narrower), anchored to the bottom-left.
              Positioned(
                left: 0,
                bottom: 0,
                width: 310 * s,
                height: 551.829 * s,
                child: SvgPicture.asset(
                  '$_asset/hill-front.svg',
                  fit: BoxFit.fill,
                ),
              ),
              // Sun, upper-left.
              Positioned(
                left: 9 * s,
                top: 92 * s,
                width: 120 * s,
                height: 120 * s,
                child: SvgPicture.asset('$_asset/sun.svg'),
              ),
              // Clouds.
              Positioned(
                left: -21 * s,
                top: 184 * s,
                width: 97.96 * s,
                height: 60 * s,
                child: SvgPicture.asset('$_asset/cloud.svg', fit: BoxFit.fill),
              ),
              Positioned(
                left: 356 * s,
                top: 158 * s,
                width: 97.96 * s,
                height: 60 * s,
                child: SvgPicture.asset('$_asset/cloud.svg', fit: BoxFit.fill),
              ),
              child,
            ],
          );
        },
      ),
    );
  }
}
