// Mango "Shape B" CTA — ported from the frontend prototype's EllaPrimaryButton.
// Diagonal corners, mango gradient, stamp-press shadow. Used for "Start Talking".

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme_colors.dart';

class EllaPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final bool uppercase;
  final BorderRadius borderRadius;

  const EllaPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
    this.uppercase = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<EllaPrimaryButton> createState() => _EllaPrimaryButtonState();
}

class _EllaPrimaryButtonState extends State<EllaPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final shadowOffset = _pressed ? const Offset(0, 1) : const Offset(0, 5);
    final translateY = _pressed ? 4.0 : 0.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        curve: Curves.ease,
        transform: Matrix4.translationValues(0, translateY, 0),
        width: double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [EllaColors.mangoTop, EllaColors.mangoMain],
          ),
          borderRadius: widget.borderRadius,
          boxShadow: [
            BoxShadow(
              color: EllaColors.mangoDark,
              offset: shadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.uppercase ? widget.label.toUpperCase() : widget.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A2200),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
