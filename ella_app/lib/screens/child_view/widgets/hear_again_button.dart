import 'package:flutter/material.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../services/audio_service.dart';

/// Reusable "Hear Again" text button component used across the app.
///
/// Features:
/// - Volume icon + semi-bold "Hear Again" text label.
/// - Tactile audio feedback on tap via `withTapClick`.
/// - Supports `disabled` state (dimmed opacity + unclickable).
class HearAgainButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool disabled;
  final double iconSize;
  final double fontSize;

  const HearAgainButton({
    super.key,
    this.onTap,
    this.disabled = false,
    this.iconSize = 16,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled
        ? EllaColors.textSecondary.withValues(alpha: 0.4)
        : EllaColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled || onTap == null ? null : withTapClick(onTap!),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Opacity(
          opacity: disabled ? 0.5 : 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.volume_up_outlined,
                size: iconSize,
                color: effectiveColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Hear Again',
                style: EllaFonts.body(
                  TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: effectiveColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alias for backwards compatibility & naming preference.
typedef HearAgainTextButton = HearAgainButton;
