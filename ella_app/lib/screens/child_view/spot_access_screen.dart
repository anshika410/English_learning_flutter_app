// Early-access welcome screen — shown once, right after login, to students
// whose email marks them as part of NavGurukul's small early-access group.
// Sits between login and the name/age onboarding (see RootGate in app.dart).

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ella_smooth_shape.dart';
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
                          IgnorePointer(
                            child: Container(
                              width: 260,
                              height: 260,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    EllaColors.greenMain.withValues(
                                      alpha: 0.28,
                                    ),
                                    EllaColors.greenMain.withValues(
                                      alpha: 0.12,
                                    ),
                                    EllaColors.greenMain.withValues(alpha: 0),
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                              ),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: SvgPicture.asset(
                              'assets/homescreen/new/Plant.svg',
                            ),
                          ),
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
                      'NavGurukul has unlocked full Ella access for you as part of your English learning.',
                      textAlign: TextAlign.center,
                      style: EllaTextStyles.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    const _SpotAccessInfoStrip(),
                    const SizedBox(height: 24),
                    Text(
                      'You are all set!',
                      textAlign: TextAlign.center,
                      style: EllaTextStyles.bodyBase.copyWith(
                        color: EllaColors.berryMain,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: EllaPrimaryButton(
                        label: 'Meet Ella',
                        height: 56,
                        onTap: onContinue,
                        labelChild: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Meet Ella',
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

/// "zoSpeak access - worth ₹499/month" info strip shown under the welcome
/// copy — a light card pairing the security badge with the plan's value.
class _SpotAccessInfoStrip extends StatelessWidget {
  const _SpotAccessInfoStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          SvgPicture.asset('assets/auth/security-badge.svg', height: 24),
          Text.rich(
            TextSpan(
              style: EllaTextStyles.bodyBase,
              children: [
                const TextSpan(text: 'Ella access - worth '),
                TextSpan(
                  text: '₹499',
                  style: EllaTextStyles.bodyBase.copyWith(
                    fontWeight: FontWeight.w700,
                    color: EllaColors.berryDark,
                  ),
                ),
                const TextSpan(text: '/month'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
