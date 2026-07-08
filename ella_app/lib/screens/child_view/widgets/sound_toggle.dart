// Functional pill toggle styled to the Figma "ToggleRight" glyph on the Profile
// screen's Sound Effects card: berry track + white knob when on, muted track +
// left knob when off. Replaces a raw [Switch] so the look matches the design
// while keeping the on/off behaviour.

import 'package:flutter/material.dart';

import '../../../core/theme_colors.dart';

class SoundToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SoundToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const width = 56.0;
    const height = 32.0;
    const knob = 24.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: value ? EllaColors.berryMain : EllaColors.borderStrong,
          borderRadius: BorderRadius.circular(height),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob,
            height: knob,
            decoration: const BoxDecoration(
              color: EllaColors.onPrimary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
