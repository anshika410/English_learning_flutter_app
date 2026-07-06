// Shared backdrop for the pre-auth onboarding screens (Splash, Login, Magic
// Link) — Figma "Onboarding" frames: a soft peach→cyan sky over two rolling
// green hills, dressed with the SAME blooming skill plants the Garden screen
// uses (assets/garden/plants/*-bloom.svg), gently swaying like they do there.
// Content is layered on top via [child].

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingScenery extends StatelessWidget {
  final Widget child;

  const OnboardingScenery({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Sky: soft peach easing into light cyan (Figma splash/login gradient).
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFEDDF), // soft peach
            Color(0xFFE5F9F6), // light cyan
          ],
          stops: [0.0, 0.4],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Rolling hills anchored to the bottom.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 150,
            child: CustomPaint(painter: _HillsPainter()),
          ),
          // Garden skill blooms — marigold (vocab) left; purple (grammar) +
          // rose (fluency) right, matching the Figma corner arrangement.
          const Positioned(
            left: 20,
            bottom: 26,
            child: _SwayingBloom(
              asset: 'assets/garden/plants/vocab-bloom.svg',
              height: 64,
              phaseMs: 0,
            ),
          ),
          const Positioned(
            right: 58,
            bottom: 54,
            child: _SwayingBloom(
              asset: 'assets/garden/plants/grammar-bloom.svg',
              height: 58,
              phaseMs: 900,
            ),
          ),
          const Positioned(
            right: 14,
            bottom: 18,
            child: _SwayingBloom(
              asset: 'assets/garden/plants/fluency-bloom.svg',
              height: 72,
              phaseMs: 1700,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// A garden bloom that sways about its base (±2.2°, 3600ms ping-pong) — the same
// idle motion as the Garden screen's _Plant sway, staggered by [phaseMs].
class _SwayingBloom extends StatefulWidget {
  final String asset;
  final double height;
  final int phaseMs;

  const _SwayingBloom({
    required this.asset,
    required this.height,
    required this.phaseMs,
  });

  @override
  State<_SwayingBloom> createState() => _SwayingBloomState();
}

class _SwayingBloomState extends State<_SwayingBloom>
    with SingleTickerProviderStateMixin {
  static const double _maxRad = 2.2 * math.pi / 180;

  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  late final Animation<double> _angle = Tween<double>(
    begin: -_maxRad,
    end: _maxRad,
  ).animate(CurvedAnimation(parent: _sway, curve: Curves.easeInOut));

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations || _started) return;
    _started = true;
    Future.delayed(Duration(milliseconds: widget.phaseMs), () {
      if (mounted) _sway.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sway,
      builder: (_, child) => Transform.rotate(
        angle: _angle.value,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: SvgPicture.asset(widget.asset, height: widget.height),
    );
  }
}

class _HillsPainter extends CustomPainter {
  const _HillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Back hill (lightest green).
    paint.color = const Color(0xFFD6EFD2);
    final back = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.4,
        size.width,
        size.height * 0.8,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, paint);

    // Front hill (vibrant green).
    paint.color = const Color(0xFFA5D166);
    final front = Path()
      ..moveTo(0, size.height * 0.9)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.6,
        size.width * 0.6,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(front, paint);
  }

  @override
  bool shouldRepaint(covariant _HillsPainter oldDelegate) => false;
}
