import 'package:flutter/material.dart';
import '../../../../core/ella_smooth_shape.dart';
import '../../../../core/text_styles.dart';
import '../../../../core/theme_colors.dart';
import '../../widgets/zoe_mascot.dart';

class PlacementResultCard extends StatelessWidget {
  final String name;
  final String levelTitle; // e.g. "Lv. 3 Everyday Talk"
  final bool isLoading;
  final bool speaking;

  const PlacementResultCard({
    super.key,
    required this.name,
    required this.levelTitle,
    this.isLoading = false,
    this.speaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mascotSize = (size.height * 0.14).clamp(90.0, 115.0);
    final verticalGap = (size.height * 0.025).clamp(14.0, 24.0);
    final cardPadding = (size.height * 0.022).clamp(14.0, 22.0);

    if (isLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: (size.height * 0.04).clamp(16.0, 32.0)),
          ZoeMascot(
            mode: ZoeMascotMode.thinking,
            size: mascotSize,
          ),
          SizedBox(height: verticalGap),
          const CircularProgressIndicator(
            color: EllaColors.berryMain,
            strokeWidth: 3,
          ),
          SizedBox(height: verticalGap),
          Text(
            'Evaluating your English level...',
            textAlign: TextAlign.center,
            style: EllaFonts.body(
              const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EllaColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: (size.height * 0.01).clamp(4.0, 10.0)),
        ZoeMascot(
          mode: speaking ? ZoeMascotMode.speaking : ZoeMascotMode.listening,
          size: mascotSize,
        ),
        SizedBox(height: verticalGap),

        // "Hooray! 🥳 \n That's a fantastic start."
        Text(
          'Hooray! 🥳',
          textAlign: TextAlign.center,
          style: EllaFonts.bricolage(
            TextStyle(
              fontSize: (size.width * 0.06).clamp(22.0, 25.0),
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: EllaColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "That's a fantastic start.",
          textAlign: TextAlign.center,
          style: EllaFonts.bricolage(
            TextStyle(
              fontSize: (size.width * 0.05).clamp(18.0, 21.0),
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: EllaColors.ink,
            ),
          ),
        ),
        SizedBox(height: verticalGap),

        // Starting level card matching original Figma specification
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: cardPadding, horizontal: 18),
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
