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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: onBack != null
                    ? _CircleControl(
                        key: const ValueKey('placement-garden-back'),
                        fill: EllaColors.greenLight,
                        ring: EllaColors.greenDeep,
                        size: 32,
                        onTap: onBack!,
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: EllaColors.greenDeep,
                        ),
                      )
                    : const SizedBox(width: 32, height: 32),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: EllaColors.surface,
                    borderRadius: BorderRadius.circular(11.16),
                    border: Border.all(color: EllaColors.border, width: 2.79),
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
                      SvgPicture.asset(_kSeedbedIcon, width: 24, height: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Sunrise Seedbed',
                        style: EllaTextStyles.gardenHeaderChip,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 40,
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child:
                    trailing ??
                    (onSound != null
                        ? _CircleControl(
                            fill: EllaColors.berryMain,
                            ring: EllaColors.berryMain,
                            size: 32,
                            onTap: onSound!,
                            child: const Icon(
                              Icons.volume_up_rounded,
                              size: 17,
                              color: EllaColors.onPrimary,
                            ),
                          )
                        : const SizedBox(width: 32, height: 32)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "$name's Garden",
          style: EllaTextStyles.gardenHeaderTitle,
          textAlign: TextAlign.center,
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
  final double size;

  const _CircleControl({
    super.key,
    required this.fill,
    required this.ring,
    required this.child,
    required this.onTap,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 2.4),
        ),
        child: child,
      ),
    );
  }
}
