// A small vertical "bob" wrapper. Whenever [trigger] changes to a new value,
// the child gently lifts and settles — used on the home CTA to signal that the
// selected topic changed. Subtle by design; respects "reduce motion".

import 'dart:math' as math;

import 'package:flutter/material.dart';

class ShakeOnChange extends StatefulWidget {
  /// When this value changes (compared with `==`), the bob plays.
  final Object? trigger;
  final Widget child;
  final Duration duration;
  final double distance;

  const ShakeOnChange({
    super.key,
    required this.trigger,
    required this.child,
    this.duration = const Duration(milliseconds: 480),
    this.distance = 5,
  });

  @override
  State<ShakeOnChange> createState() => _ShakeOnChangeState();
}

class _ShakeOnChangeState extends State<ShakeOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(ShakeOnChange old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger &&
        !MediaQuery.of(context).disableAnimations) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Eased, damped vertical bob: ~1.5 gentle oscillations that fade to
        // rest. Negative dy lifts the button up first for a light, springy feel.
        final t = Curves.easeOut.transform(_controller.value);
        final dy = t == 0
            ? 0.0
            : -math.sin(t * math.pi * 3) * widget.distance * (1 - t);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: widget.child,
    );
  }
}
