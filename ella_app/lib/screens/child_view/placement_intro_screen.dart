// Placement intro — the first-run "Homescreen" (Figma "Placement Flow").
// Shown by RootGate before a student has been levelled: the garden sky, Zoe, a
// warm "tell me about yourself" greeting, and a single "Let's Talk" CTA that
// starts the voice placement screening. Deliberately simpler than HomeScreen —
// no topic chips or Last-time card, since there's no history or level yet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/placement_provider.dart';
import '../../providers/service_providers.dart';
import 'home_screen.dart' show kHomeChildName;
import 'placement_screen.dart';
import 'widgets/ella_primary_button.dart';
import 'widgets/garden_sky_background.dart';
import 'widgets/speak_again_label.dart';
import 'widgets/zoe_mascot.dart';

const String _kVoiceIcon = 'assets/homescreen/new/UserSound.svg';

const String _kGreeting =
    "I'd love to know more about you! Tell me about your world. "
    "It'll help your garden grow.";

class PlacementIntroScreen extends ConsumerStatefulWidget {
  const PlacementIntroScreen({super.key});

  @override
  ConsumerState<PlacementIntroScreen> createState() =>
      _PlacementIntroScreenState();
}

class _PlacementIntroScreenState extends ConsumerState<PlacementIntroScreen> {
  @override
  void initState() {
    super.initState();
    // Greet the child aloud as soon as the screen appears (not only when they
    // tap "Speak Again").
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakGreeting());
  }

  Future<void> _speakGreeting() async {
    try {
      await ref.read(ttsProvider).speak(_kGreeting);
    } catch (_) {}
  }

  void _startPlacement() {
    // Start each screening from a clean slate (a prior End left stale state).
    ref.invalidate(placementProvider);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlacementScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mascotW = (MediaQuery.of(context).size.width * 0.35).clamp(
      128.0,
      168.0,
    );
    // Prefer the name the child typed during onboarding; fall back to the demo
    // placeholder if it isn't cached yet.
    final childName =
        ref.watch(onboardingProvider).valueOrNull?.name ?? kHomeChildName;

    return GardenSkyBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Hi, $childName!',
                    style: EllaTextStyles.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ZoeMascot(
                      mode: ZoeMascotMode.listening,
                      size: mascotW,
                      reducedMotion: MediaQuery.of(context).disableAnimations,
                    ),
                    const SizedBox(height: 24),
                    _GreetingCard(onSpeak: _speakGreeting),
                    const SizedBox(height: 24),
                    EllaPrimaryButton(
                      label: "Let's Talk",
                      height: 60,
                      leading: SvgPicture.asset(
                        _kVoiceIcon,
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          EllaColors.onPrimary,
                          BlendMode.srcIn,
                        ),
                      ),
                      onTap: _startPlacement,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final VoidCallback onSpeak;
  const _GreetingCard({required this.onSpeak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EllaColors.info, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SpeakAgainLabel(onTap: onSpeak),
          const SizedBox(height: 6),
          Text(_kGreeting, style: EllaTextStyles.bodySemibold),
        ],
      ),
    );
  }
}
