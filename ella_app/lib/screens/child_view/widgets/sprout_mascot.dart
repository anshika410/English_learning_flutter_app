// Zoe, the sprout mascot (new garden design). Renders the open-mouth SVG while
// she's speaking and the closed-mouth SVG when listening/idle. Static swap for
// now — micro-animation (bob/scale) is a later pass. Reused by the conversation
// screen; the home screen can adopt it too.

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _kOpen = 'assets/homescreen/new/mascot-open.svg';
const String _kClosed = 'assets/homescreen/new/mascot-mouthclose.svg';

// Native artboard aspect (206 x 244).
const double _kAspect = 244 / 206;

class SproutMascot extends StatelessWidget {
  /// Open mouth (speaking) vs closed smile (listening/idle).
  final bool speaking;
  final double size; // width; height derived from the artboard aspect.

  const SproutMascot({super.key, required this.speaking, this.size = 160});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: SvgPicture.asset(
        speaking ? _kOpen : _kClosed,
        key: ValueKey<bool>(speaking),
        width: size,
        height: size * _kAspect,
      ),
    );
  }
}
