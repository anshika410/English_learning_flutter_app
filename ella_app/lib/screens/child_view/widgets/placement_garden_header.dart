// Placement-garden header — Figma first-sprout / placement-garden frames:
// a round back control (left), the "Sunrise Seedbed" chip (centre, with its
// dedicated seedbed icon), a berry sound button (right), and the
// "{Name}'s Garden" title beneath. Shared by the onboarding first-sprout intro
// and the placement garden screen; back/sound controls only render when their
// callbacks are provided.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../services/audio_service.dart';

const String _kSeedbedIcon = 'assets/garden/plants/Sunrise Seedbed Icon 1.svg';

class PlacementGardenHeader extends StatelessWidget {
  final String name;

  /// Round green back control on the left (hidden when null).
  final VoidCallback? onBack;

  /// Berry sound button on the right (hidden when null) — e.g. replays Zoe's
  /// nudge line aloud. Ignored when [trailing] is provided.
  final VoidCallback? onSound;

  /// Custom widget for the right slot (e.g. the garden mute toggle). Takes
  /// precedence over [onSound].
  final Widget? trailing;

  const PlacementGardenHeader({
    super.key,
    required this.name,
    this.onBack,
    this.onSound,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (onBack != null)
              _CircleControl(
                fill: EllaColors.surface,
                ring: EllaColors.greenDark,
                onTap: onBack!,
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: EllaColors.greenDeep,
                ),
              )
            else
              const SizedBox(width: 38),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: EllaColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: EllaColors.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(_kSeedbedIcon, height: 18),
                      const SizedBox(width: 6),
                      Text('Sunrise Seedbed', style: EllaTextStyles.caption),
                    ],
                  ),
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onSound != null)
              _CircleControl(
                fill: EllaColors.berryMain,
                ring: EllaColors.berryDeep,
                onTap: onSound!,
                child: const Icon(
                  Icons.volume_up_rounded,
                  size: 18,
                  color: EllaColors.onPrimary,
                ),
              )
            else
              const SizedBox(width: 38),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "$name's Garden",
          style: EllaTextStyles.titleSmall.copyWith(fontSize: 18),
        ),
      ],
    );
  }
}

class _CircleControl extends StatelessWidget {
  final Color fill;
  final Color ring;
  final Widget child;
  final VoidCallback onTap;

  const _CircleControl({
    required this.fill,
    required this.ring,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 2),
        ),
        child: child,
      ),
    );
  }
}
