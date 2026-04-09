import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ella_theme.dart';
import '../widgets/ella_primary_button.dart';
import 'placement_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _navigateToPlacement(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context2, animation, secondary) =>
            const PlacementScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context2, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: Stack(
        children: [
          // Animated confetti dots across the full background
          const IgnorePointer(child: _ConfettiBackground()),

          // Decorative corner blocks (behind everything, non-interactive)
          const IgnorePointer(child: _CornerBlocks()),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Zoe mascot — animated webp looping inside circle
                  const _ZoeMascot(),

                  const SizedBox(height: 20),

                  // Heading — extra bold
                  Text(
                    'Hey, I am Zoe! 🙌',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Chillax',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: EllaColors.neutralPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Warm support line
                  Text(
                    'Your English speaking buddy, let\'s practice one easy step at a time',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: EllaColors.neutralSecondary,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 24),

                  EllaPrimaryButton(
                    label: 'Start learning',
                    onTap: () => _navigateToPlacement(context),
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Zoe Mascot ──────────────────────────────────────────────────────────────

class _ZoeMascot extends StatelessWidget {
  const _ZoeMascot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EllaColors.zoeMintLight,
        boxShadow: [
          BoxShadow(
            color: EllaColors.neutralMuted.withValues(alpha: 0.40),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 3),
            blurRadius: 14,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/mascot-animations/listening.webp',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

// ─── Corner Blocks ───────────────────────────────────────────────────────────

class _CornerBlocks extends StatelessWidget {
  const _CornerBlocks();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-left — Mango (orange) — tallest, most dominant
        _CornerBlock(
          color: EllaColors.mangoMain,
          alignment: Alignment.topLeft,
          xOffset: -88,
          yOffset: -96,
          rotationDeg: -20,
          width: 170,
          height: 360,
        ),
        // Top-right — Sky (blue)
        _CornerBlock(
          color: EllaColors.skyMain,
          alignment: Alignment.topRight,
          xOffset: 88,
          yOffset: -96,
          rotationDeg: 20,
          width: 170,
          height: 350,
        ),
        // Bottom-left — Sunny Yellow
        _CornerBlock(
          color: EllaColors.sunnyYellow,
          alignment: Alignment.bottomLeft,
          xOffset: -88,
          yOffset: 92,
          rotationDeg: 20,
          width: 180,
          height: 340,
        ),
        // Bottom-right — Rose (pink)
        _CornerBlock(
          color: EllaColors.roseMain,
          alignment: Alignment.bottomRight,
          xOffset: 88,
          yOffset: 92,
          rotationDeg: -20,
          width: 180,
          height: 340,
        ),
      ],
    );
  }
}

class _CornerBlock extends StatelessWidget {
  final Color color;
  final Alignment alignment;
  final double xOffset;
  final double yOffset;
  final double rotationDeg;
  final double width;
  final double height;

  const _CornerBlock({
    required this.color,
    required this.alignment,
    required this.xOffset,
    required this.yOffset,
    required this.rotationDeg,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(xOffset, yOffset),
        child: Transform.rotate(
          angle: rotationDeg * math.pi / 180,
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(painter: _BlockPainter(color: color)),
          ),
        ),
      ),
    );
  }
}

// ─── Block painter (solid fill + subtle monochrome dots) ─────────────────────

class _BlockPainter extends CustomPainter {
  final Color color;

  _BlockPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);

    final dotColor = Color.lerp(color, Colors.black, 0.22)!;
    final dotPaint = Paint()..color = dotColor.withValues(alpha: 0.18);
    const spacing = 14.0;
    const radius = 1.4;

    for (double y = spacing * 0.7; y < size.height; y += spacing) {
      for (double x = spacing * 0.7; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_BlockPainter oldDelegate) => oldDelegate.color != color;
}

// ─── Confetti Background ─────────────────────────────────────────────────────

// Each entry: (normalised x, normalised y, color index, radius)
const List<_DotData> _kDots = [
  _DotData(0.08, 0.07, 0, 4.0),
  _DotData(0.28, 0.10, 2, 3.8),
  _DotData(0.54, 0.09, 1, 3.2),
  _DotData(0.82, 0.12, 3, 4.4),
  _DotData(0.16, 0.25, 3, 4.0),
  _DotData(0.44, 0.21, 0, 3.4),
  _DotData(0.72, 0.24, 1, 4.0),
  _DotData(0.90, 0.30, 2, 3.4),
  _DotData(0.09, 0.40, 0, 4.2),
  _DotData(0.33, 0.37, 2, 3.4),
  _DotData(0.58, 0.42, 1, 4.0),
  _DotData(0.86, 0.47, 3, 3.6),
  _DotData(0.18, 0.56, 0, 3.6),
  _DotData(0.48, 0.60, 1, 4.0),
  _DotData(0.75, 0.55, 2, 4.4),
  _DotData(0.92, 0.64, 3, 3.2),
  _DotData(0.07, 0.71, 0, 4.0),
  _DotData(0.31, 0.74, 1, 3.2),
  _DotData(0.60, 0.78, 2, 3.8),
  _DotData(0.84, 0.83, 0, 4.0),
  _DotData(0.14, 0.88, 3, 3.4),
  _DotData(0.45, 0.92, 2, 3.8),
  _DotData(0.71, 0.89, 1, 3.6),
  _DotData(0.90, 0.93, 0, 3.2),
];

class _DotData {
  final double x;
  final double y;
  final int colorIdx;
  final double radius;

  const _DotData(this.x, this.y, this.colorIdx, this.radius);
}

const List<Color> _kDotColors = [
  EllaColors.mangoMain,
  EllaColors.skyMain,
  EllaColors.limeMain,
  EllaColors.roseMain,
];

class _ConfettiBackground extends StatefulWidget {
  const _ConfettiBackground();

  @override
  State<_ConfettiBackground> createState() => _ConfettiBackgroundState();
}

class _ConfettiBackgroundState extends State<_ConfettiBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
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
      builder: (context, _) {
        return CustomPaint(
          painter: _ConfettiPainter(animValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double animValue;

  _ConfettiPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _kDots.length; i++) {
      final dot = _kDots[i];
      final color = _kDotColors[dot.colorIdx];
      final paint = Paint()..color = color.withValues(alpha: 0.38);

      // Each dot gets a unique phase so they don't all move in sync
      final phase = (i / _kDots.length) * math.pi * 2;
      final driftY = math.sin(animValue * math.pi * 2 + phase) * 5.0;

      final cx = dot.x * size.width;
      final cy = dot.y * size.height + driftY;

      canvas.drawCircle(Offset(cx, cy), dot.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}
