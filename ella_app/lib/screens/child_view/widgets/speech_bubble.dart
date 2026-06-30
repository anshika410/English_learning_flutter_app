// Cream speech bubble used on the Home + Session screens. Optional upward tail
// (a small notch) points toward the mascot. An optional [footer] (e.g. the
// "Start Talking" button) sits inside the bubble, matching the Figma homescreen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme_colors.dart';

class SpeechBubble extends StatelessWidget {
  final String text;
  final bool showTail;
  final bool italic;
  final Widget? footer;

  const SpeechBubble({
    super.key,
    required this.text,
    this.showTail = false,
    this.italic = false,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: EllaColors.bubbleSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: GoogleFonts.baloo2(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              color: italic ? EllaColors.secondary : EllaColors.bubbleText,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 14),
            footer!,
          ],
        ],
      ),
    );

    if (!showTail) return bubble;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(22, 11), painter: _TailPainter()),
        bubble,
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = EllaColors.bubbleSurface;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => false;
}
