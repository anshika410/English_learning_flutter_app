// Offline screen — shown over whatever the child was on when the device loses
// its network. One calm screen on the shared garden sky: the listening mascot,
// a short "check your network" line, and a retry button that re-checks
// connectivity. Reuses GardenSkyBackground + ZoeMascot so it reads as part of
// the same world, not a system error page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../providers/connectivity_provider.dart';
import 'widgets/ella_primary_button.dart';
import 'widgets/garden_sky_background.dart';
import 'widgets/zoe_mascot.dart';

class OfflineScreen extends ConsumerWidget {
  const OfflineScreen({super.key});

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
                    mode: ZoeMascotMode.listening,
                    size: mascotSize,
                    reducedMotion: reducedMotion,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "No Internet Connection",
                    textAlign: TextAlign.center,
                    style: EllaTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your internet connection and try again.',
                    textAlign: TextAlign.center,
                    style: EllaTextStyles.authBody.copyWith(
                      color: EllaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 200,
                    child: EllaPrimaryButton(
                      label: 'Refresh',
                      height: 56,
                      leading: const Icon(
                        Icons.refresh_rounded,
                        color: EllaColors.onPrimary,
                        size: 24,
                      ),
                      // Re-run the connectivity check; when the network is back
                      // the provider emits `true` and the overlay is dismissed automatically.
                      onTap: () => ref.invalidate(connectivityProvider),
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
