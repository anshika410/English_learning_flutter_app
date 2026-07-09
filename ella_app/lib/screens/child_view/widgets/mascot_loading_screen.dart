import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import 'garden_sky_background.dart';
import 'zoe_mascot.dart';

class MascotLoadingScreen extends ConsumerWidget {
  final String message;

  const MascotLoadingScreen({
    super.key,
    this.message = 'Loading...',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final mascotSize = (MediaQuery.sizeOf(context).shortestSide * 0.42)
        .clamp(132.0, 180.0);

    return GardenSkyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZoeMascot(
                    mode: ZoeMascotMode.thinking,
                    size: mascotSize,
                    reducedMotion: reducedMotion,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: EllaTextStyles.bodySemibold.copyWith(
                      color: EllaColors.greenDeep,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 140,
                    child: LinearProgressIndicator(
                      color: EllaColors.greenMain,
                      backgroundColor: EllaColors.border,
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
