// Small decorative leaves that drift around Zoe on celebration screens
// (e.g. the early-access "spot" reveal). Purely ambient — no interaction.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FloatingLeaf extends StatefulWidget {
  final String asset;
  final double size;
  final int phaseMs;
  final bool reducedMotion;

  const FloatingLeaf({
    super.key,
    required this.asset,
    this.size = 24,
    this.phaseMs = 0,
    this.reducedMotion = false,
  });

  @override
  State<FloatingLeaf> createState() => _FloatingLeafState();
}

class _FloatingLeafState extends State<FloatingLeaf>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  late final Animation<double> _bob = Tween<double>(
    begin: -8,
    end: 8,
  ).animate(CurvedAnimation(parent: _drift, curve: Curves.easeInOut));
  late final Animation<double> _tilt = Tween<double>(
    begin: -0.12,
    end: 0.12,
  ).animate(CurvedAnimation(parent: _drift, curve: Curves.easeInOut));

  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Touch _bob/_tilt (not just _drift) here so both `late final` fields
    // initialize while the element is active. Otherwise, when build() never
    // needs them (reducedMotion == true), they stay uninitialized until
    // dispose() touches _drift — creating a ticker on an already-deactivated
    // element and crashing.
    _bob;
    _tilt;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.reducedMotion || _started) return;
    _started = true;
    Future.delayed(Duration(milliseconds: widget.phaseMs), () {
      if (mounted) _drift.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaf = SvgPicture.asset(widget.asset, height: widget.size);
    if (widget.reducedMotion) return leaf;
    return AnimatedBuilder(
      animation: _drift,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _bob.value),
        child: Transform.rotate(angle: _tilt.value, child: child),
      ),
      child: leaf,
    );
  }
}
