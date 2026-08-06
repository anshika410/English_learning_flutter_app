// Botanical home-screen backdrop. A single design-exported scene SVG
// (sky→green gradient, layered hills, a soft bush, daisies and grass tufts —
// no sun) drawn full-bleed behind screen content. This is the canonical scene
// shared by Home, onboarding, placement, loading, conversation, and error views.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

typedef ContentBackgroundBuilder = Widget Function(Widget child);

class HomeSceneBackground extends StatelessWidget {
  final Widget child;

  const HomeSceneBackground({super.key, required this.child});

  static const String _scene = 'assets/homescreen/new/home-background.svg';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SvgPicture.asset(
          _scene,
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
        ),
        child,
      ],
    );
  }
}
