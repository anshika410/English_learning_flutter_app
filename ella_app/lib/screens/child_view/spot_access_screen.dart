// Early-access welcome screen — shown once, right after login, to students
// whose email marks them as part of NavGurukul's small early-access group.
// Sits between login and the name/age onboarding (see RootGate in app.dart).

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import 'widgets/ella_primary_button.dart';
import 'widgets/floating_leaf.dart';
import 'widgets/home_scene_background.dart';
import 'widgets/mascot_glow.dart';
import 'widgets/zoe_mascot.dart';

class SpotAccessScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const SpotAccessScreen({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return HomeSceneBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 56,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            child: SvgPicture.asset(
                              'assets/gardent-view/clouds-weather.svg',
                              key: const Key('spot-access-cloud-left'),
                              width: 56,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: SvgPicture.asset(
                              'assets/gardent-view/clouds-weather.svg',
                              key: const Key('spot-access-cloud-right'),
                              width: 56,
                            ),
                          ),
                          MascotGlow(size: 260, reducedMotion: reducedMotion),
                          Positioned(
                            right: 30,
                            bottom: 20,
                            child: FloatingLeaf(
                              asset: 'assets/decorations/leaf-3.svg',
                              size: 20,
                              phaseMs: 1000,
                              reducedMotion: reducedMotion,
                            ),
                          ),
                          Positioned(
                            left: 24,
                            bottom: 10,
                            child: FloatingLeaf(
                              asset: 'assets/decorations/leaf-2.svg',
                              size: 18,
                              phaseMs: 1500,
                              reducedMotion: reducedMotion,
                            ),
                          ),
                          ZoeMascot(
                            mode: ZoeMascotMode.idle,
                            size: 168,
                            reducedMotion: reducedMotion,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "You've Got a Spot",
                      textAlign: TextAlign.center,
                      style: EllaTextStyles.headline,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: EllaColors.borderStrong,
                            thickness: 1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: _LeafCluster(),
                        ),
                        Expanded(
                          child: Divider(
                            color: EllaColors.borderStrong,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'NavGurukul is providing you full access to ZoSpeak as part of your English learning',
                      textAlign: TextAlign.center,
                      style: EllaTextStyles.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You are all set!',
                      textAlign: TextAlign.center,
                      style: EllaTextStyles.bodySemiboldLarge.copyWith(
                        color: EllaColors.berryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: EllaPrimaryButton(
                        label: 'Meet Zoe',
                        height: 56,
                        onTap: onContinue,
                        labelChild: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Meet Zoe',
                              style: EllaTextStyles.button.copyWith(
                                color: EllaColors.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: EllaColors.onPrimary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small static ornament for the divider row: three of the same leaf
/// silhouettes used by [FloatingLeaf], fanned into a single cluster icon.
class _LeafCluster extends StatelessWidget {
  const _LeafCluster();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            bottom: 1,
            child: Transform.rotate(
              angle: -0.5,
              child: SvgPicture.asset(
                'assets/decorations/leaf-2.svg',
                height: 14,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 1,
            child: Transform.rotate(
              angle: 0.5,
              child: SvgPicture.asset(
                'assets/decorations/leaf-2.svg',
                height: 14,
              ),
            ),
          ),
          SvgPicture.asset('assets/decorations/leaf-1.svg', height: 18),
        ],
      ),
    );
  }
}
