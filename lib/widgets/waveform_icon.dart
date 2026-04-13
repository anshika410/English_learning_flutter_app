import 'package:flutter/material.dart';

/// Animated 5-bar waveform shown inside the mic button while listening.
/// Bars pulse with staggered phase offsets giving a wave-like effect.
class WaveformIcon extends StatefulWidget {
  const WaveformIcon({super.key});

  @override
  State<WaveformIcon> createState() => _WaveformIconState();
}

class _WaveformIconState extends State<WaveformIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const phases = [0.0, 0.3, 0.6, 0.3, 0.0];
    const maxBarHeight = 18.0;
    const minBarHeight = 4.0;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(5, (i) {
            final t = (_ctrl.value + phases[i]) % 1.0;
            final height = minBarHeight +
                (maxBarHeight - minBarHeight) * (0.5 + 0.5 * _triangle(t));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  static double _triangle(double t) {
    if (t < 0.5) return t * 2;
    return (1.0 - t) * 2;
  }
}
