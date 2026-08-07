// A soft radial glow behind Zoe for celebration / spotlight moments. Colours
// follow the A1 "Morning Meadow" sun-glow palette (docs/ella-design-system.md)
// — a warm yellow, as if sunlight were coming from behind Zoe.

import 'package:flutter/material.dart';

class MascotGlow extends StatefulWidget {
  final double size;
  final bool reducedMotion;

  const MascotGlow({super.key, this.size = 260, this.reducedMotion = false});

  @override
  State<MascotGlow> createState() => _MascotGlowState();
}

class _MascotGlowState extends State<MascotGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1.06,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    // Touch _scale (not just _pulse) here so both `late final` fields
    // initialize while the element is active. Otherwise, when this widget
    // never needs _scale during build() (reducedMotion == true), it stays
    // uninitialized until dispose() touches _pulse — creating a ticker on an
    // already-deactivated element and crashing.
    _scale;
    if (!widget.reducedMotion) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reducedMotion) {
      return _glow(1);
    }
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: _glow(1),
    );
  }

  Widget _glow(double scale) {
    return IgnorePointer(
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Color(0xCCFFE066), // soft yellow core
              Color(0x70FFD24D), // warm golden middle
              Color(0x00FFB84D), // transparent amber outer falloff
            ],
            stops: [0.0, 0.52, 1.0],
          ),
        ),
      ),
    );
  }
}
