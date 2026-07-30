import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _wildflowers = 'assets/garden/plants/wildflowers 2.svg';

/// The reusable sky, sun, and hill painter from the placement garden.
class PlacementGardenBackdrop extends StatelessWidget {
  const PlacementGardenBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PlacementGardenBackdropPainter());
  }
}

/// The two wildflower accents shared by the placement screen and garden
/// loading/error states.
class PlacementGardenWildflowers extends StatelessWidget {
  final double scale;
  final double rightTop;
  final double leftTop;

  const PlacementGardenWildflowers({
    super.key,
    required this.scale,
    required this.rightTop,
    required this.leftTop,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 34 * scale,
          top: rightTop,
          child: SvgPicture.asset(_wildflowers, width: 36 * scale),
        ),
        Positioned(
          left: 32 * scale,
          top: leftTop,
          child: SvgPicture.asset(_wildflowers, width: 36 * scale),
        ),
      ],
    );
  }
}

/// Placement-garden scenery for status content before a level is known.
///
/// The plot, fence, header, and placement state remain owned by
/// `PlacementGardenScreen`; this wrapper deliberately reuses only its backdrop
/// and decorative wildflowers.
class PlacementGardenStatusBackground extends StatelessWidget {
  final Widget child;

  const PlacementGardenStatusBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / 430).clamp(0.82, 1.08);
        return Stack(
          key: const ValueKey('placement-garden-status-background'),
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(
              child: PlacementGardenBackdrop(
                key: ValueKey('placement-garden-backdrop'),
              ),
            ),
            RepaintBoundary(
              child: PlacementGardenWildflowers(
                scale: scale.toDouble(),
                rightTop: constraints.maxHeight * 0.34,
                leftTop: constraints.maxHeight * 0.75,
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}

class _PlacementGardenBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final skyRect = Offset.zero & size;
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAFDFF), Color(0xFFD9FAFF), Color(0xFFF1FFF8)],
          stops: [0, 0.55, 1],
        ).createShader(skyRect),
    );

    final sunCenter = Offset(size.width * 0.87, size.height * 0.202);
    final sunRadius = (size.width * 0.085).clamp(28.0, 36.0);
    canvas.drawCircle(
      sunCenter,
      sunRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFF1C5),
            Color(0xFFFFD77A),
            Color(0x66FFD77A),
            Color(0x00FFD77A),
          ],
          stops: [0, 0.36, 0.72, 1],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius)),
    );

    final hill = Path()
      ..moveTo(0, size.height * 0.269)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.186,
        size.width * 0.63,
        size.height * 0.204,
        size.width,
        size.height * 0.270,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      hill,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD7F2C4), Color(0xFF8DD67C), Color(0xFF4E9A45)],
              stops: [0, 0.55, 1],
            ).createShader(
              Rect.fromLTWH(
                0,
                size.height * 0.192,
                size.width,
                size.height * 0.808,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
