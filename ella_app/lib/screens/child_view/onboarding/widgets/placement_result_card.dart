import 'package:flutter/material.dart';
import '../../../../core/ella_smooth_shape.dart';
import '../../../../core/text_styles.dart';
import '../../../../core/theme_colors.dart';
import '../../widgets/zoe_mascot.dart';

class PlacementResultCard extends StatelessWidget {
  final String name;
  final String levelTitle; // e.g. "Lv. 3 Everyday Talk"

  const PlacementResultCard({
    super.key,
    required this.name,
    required this.levelTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const ZoeMascot(
          mode: ZoeMascotMode.listening,
          size: 110,
        ),
        const SizedBox(height: 20),

        // "[Name], I found a good place for you to start!"
        Text(
          '$name, I found a good place\nfor you to start!',
          textAlign: TextAlign.center,
          style: EllaFonts.bricolage(
            const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: EllaColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Starting level card matching Figma
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
          decoration: ellaSmoothDecoration(
            color: EllaColors.surface,
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: EllaColors.info, width: 2),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'YOUR STARTING LEVEL',
                textAlign: TextAlign.center,
                style: EllaFonts.body(
                  const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: EllaColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                levelTitle,
                textAlign: TextAlign.center,
                style: EllaFonts.bricolage(
                  const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: EllaColors.berryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
