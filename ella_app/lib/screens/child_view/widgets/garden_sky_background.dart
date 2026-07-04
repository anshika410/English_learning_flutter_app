// Outdoor sky + rolling green hills backdrop for the new Home screen (Figma
// "Learning Flow — Homescreen"). A bright environment-gradient sky with a warm
// sun top-left, two soft clouds, and two overlapping field hills anchored to the
// bottom. Colours come straight from the Botanical Berry environment/field
// tokens so this matches the design handoff SVG. Content is layered on top.

import 'package:flutter/material.dart';

import '../../../core/theme_colors.dart';

class GardenSkyBackground extends StatelessWidget {
  final Widget child;

  const GardenSkyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Sky: bright environment light easing into the mint surface tint.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            EllaColors.environmentLight,
            EllaColors.environmentMain,
            EllaColors.surfaceVariant,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _SkyScenePainter()),
          child,
        ],
      ),
    );
  }
}

class _SkyScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _paintSun(canvas, w, h);
    _paintClouds(canvas, w, h);
    _paintHills(canvas, w, h);
  }

  void _paintSun(Canvas canvas, double w, double h) {
    final center = Offset(w * 0.16, h * 0.16);
    final radius = w * 0.12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [
          EllaColors.warning, // #FFAA00 core
          EllaColors.warning,
          Color(0x80FFF3D4), // warm halo, fading
          Color(0x00FFF3D4), // transparent edge
        ],
        stops: [0.0, 0.42, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  void _paintClouds(Canvas canvas, double w, double h) {
    final cloud = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Left cloud, mid-sky.
    _blob(canvas, cloud, Offset(w * 0.10, h * 0.235), w * 0.09, w * 0.055);
    // Right cloud, high.
    _blob(canvas, cloud, Offset(w * 0.86, h * 0.185), w * 0.10, w * 0.058);
  }

  // A cloud as three overlapping lozenges.
  void _blob(Canvas canvas, Paint paint, Offset c, double r, double rSmall) {
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(c.translate(-r * 0.85, r * 0.25), rSmall, paint);
    canvas.drawCircle(c.translate(r * 0.85, r * 0.25), rSmall, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - r, c.dy + r * 0.1, r * 2, r * 0.7),
        Radius.circular(rSmall),
      ),
      paint,
    );
  }

  void _paintHills(Canvas canvas, double w, double h) {
    // Back hill — lighter field, gentle hump toward the right.
    final backHill = Path()
      ..moveTo(0, h * 0.62)
      ..quadraticBezierTo(w * 0.30, h * 0.50, w * 0.62, h * 0.44)
      ..quadraticBezierTo(w * 0.82, h * 0.40, w, h * 0.50)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      backHill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [EllaColors.fieldLight, EllaColors.fieldMain],
        ).createShader(Rect.fromLTWH(0, h * 0.40, w, h * 0.60)),
    );

    // Front hill — deeper field, hump toward the left, overlapping the back one.
    final frontHill = Path()
      ..moveTo(0, h * 0.74)
      ..quadraticBezierTo(w * 0.22, h * 0.63, w * 0.44, h * 0.66)
      ..quadraticBezierTo(w * 0.74, h * 0.70, w, h * 0.82)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      frontHill,
      Paint()
        // Figma foreground ground gradient (#99C963 → #8AC645), lighter than the
        // old fieldMain→fieldDark ramp.
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF99C963), Color(0xFF8AC645)],
        ).createShader(Rect.fromLTWH(0, h * 0.60, w, h * 0.40)),
    );
  }

  @override
  bool shouldRepaint(_SkyScenePainter oldDelegate) => false;
}
