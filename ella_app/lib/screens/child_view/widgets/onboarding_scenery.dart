// Shared backdrop for the pre-auth onboarding screens (Splash, Login, Magic
// Link) — Figma "Onboarding" frames: a soft peach→cyan sky over rolling green
// hills and three little blooms. The frame values are treated as proportions,
// then clamped so the scenery holds together on narrow/short phones.
// Content is layered on top via [child].

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingScenery extends StatelessWidget {
  final Widget child;

  const OnboardingScenery({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final hillWidth = math.max(width * 1.305, 400.0);
        final hillHeight = hillWidth * 660.5 / 561;
        final visibleHillHeight = _clampDouble(height * 0.116, 72, 112);
        // Blooms sized ~15% larger than before (0.122→0.140, clamps scaled).
        final plantHeight = _clampDouble(height * 0.140, 94, 131);

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
              Positioned(
                left: -width * 0.121,
                bottom: -(hillHeight - visibleHillHeight),
                width: hillWidth,
                height: hillHeight,
                child: RepaintBoundary(
                  child: SvgPicture.asset(
                    'assets/auth/onboarding-hills.svg',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              Positioned(
                left: width * 0.067,
                bottom: _clampDouble(height * 0.026, 16, 26),
                child: RepaintBoundary(
                  child: _SwayingBloom(
                    asset: 'assets/gardent-view/plannts-vocobulary-bloom.svg',
                    height: plantHeight,
                    phaseMs: 0,
                  ),
                ),
              ),
              Positioned(
                right: width * 0.13,
                bottom: _clampDouble(height * 0.044, 24, 42),
                child: RepaintBoundary(
                  child: _SwayingBloom(
                    asset: 'assets/gardent-view/plants-grammer-bloom.svg',
                    height: plantHeight,
                    phaseMs: 1200,
                  ),
                ),
              ),
              Positioned(
                right: -width * 0.004,
                bottom: _clampDouble(height * 0.022, 14, 22),
                child: RepaintBoundary(
                  child: _SwayingBloom(
                    asset: 'assets/gardent-view/plants-fluency-bloom.svg',
                    height: plantHeight,
                    phaseMs: 2400,
                  ),
                ),
              ),
              RepaintBoundary(child: child),
            ],
          ),
        );
      },
    );
  }
}

double _clampDouble(double value, double min, double max) {
  return value.clamp(min, max).toDouble();
}

// A garden bloom that sways about its base (±2.0°, 6000ms ping-pong). It is
// deliberately slower than the interactive garden plants so the auth screens
// keep their calm, idle feel.
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
  static const double _maxRad = 4.0 * math.pi / 180;

  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
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
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _sway,
      builder: (_, child) => Transform.rotate(
        angle: reducedMotion ? 0 : _angle.value,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: SvgPicture.asset(widget.asset, height: widget.height),
    );
  }
}
