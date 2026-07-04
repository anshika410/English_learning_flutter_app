import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ella_theme.dart';

/// Full-width CTA button with Ella Design System Shape B diagonal corners,
/// mango gradient fill, and stamp shadow press animation.
class EllaPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const EllaPrimaryButton({super.key, required this.label, this.onTap});

  @override
  State<EllaPrimaryButton> createState() => _EllaPrimaryButtonState();
}

class _EllaPrimaryButtonState extends State<EllaPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Bottom press-depth shadow collapses when pressed.
    final shadowOffset = _pressed ? const Offset(0, 1) : const Offset(0, 5);
    // Button translates down slightly when pressed
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
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [EllaColors.mangoTop, EllaColors.mangoMain],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(4),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: EllaColors.mangoDark,
              offset: shadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.label.toUpperCase(),
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
