// Placement complete — the "first sprout" success state (Figma "Full Bloom
// Garden & CTA to new garden"). Matches the shared mockup: the garden sky (sun +
// clouds + hills come from GardenSkyBackground), Zoe tucked top-left above a
// short congratulatory message box, a single flower gently swaying on its soil
// tile in the centre, and a large "See My Garden" CTA (plant glyph) at the
// bottom.
//
// This screen is intentionally static — it shows no placement data. After the
// screening the level/garden are read from the memory + garden APIs on the
// Garden screen; nothing else is surfaced here.
//
// By the time this shows, ChatNotifier.refreshAfterPlacement() has already run
// (memory now carries `placement`), so RootGate's root route has become the
// topic Home. "See My Garden" pops back to that Home and pushes Garden on top,
// leaving a natural back path (Garden → Home).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import 'garden_screen.dart';
import 'widgets/ella_primary_button.dart';
import 'widgets/garden_sky_background.dart';
import 'widgets/zoe_mascot.dart';

class PlacementCompleteScreen extends StatelessWidget {
  const PlacementCompleteScreen({super.key});

  void _seeMyGarden(BuildContext context) {
    // Reveal the (now placement-aware) Home, then push the Garden on top.
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          backgroundColor: Colors.transparent,
          body: GardenScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.surfaceVariant,
      body: GardenSkyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                // Zoe sits top-left, dipping into the message box's top corner.
                Align(
                  alignment: Alignment.centerLeft,
                  child: ZoeMascot(
                    mode: ZoeMascotMode.listening,
                    size: 84,
                    reducedMotion: MediaQuery.of(context).disableAnimations,
                  ),
                ),
                const SizedBox(height: 4),
                const _BloomMessageCard(),
                const Expanded(child: Center(child: _SwayingFlower())),
                EllaPrimaryButton(
                  label: 'See My Garden',
                  height: 70,
                  leading: SvgPicture.asset(
                    'assets/gardent-view/plc_plant.svg',
                    width: 26,
                    height: 26,
                    colorFilter: const ColorFilter.mode(
                      EllaColors.onPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  onTap: () => _seeMyGarden(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BloomMessageCard extends StatelessWidget {
  const _BloomMessageCard();

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
          Text('Your flower is blooming! 🌸', style: EllaTextStyles.titleSmall),
          const SizedBox(height: 6),
          Text(
            "You've got a brand new garden waiting with space for even more "
            'plants.',
            style: EllaTextStyles.bodySemibold,
          ),
        ],
      ),
    );
  }
}

// A single flower growing from a turf tile — the only element in the centre.
// The flower gently sways (rotates about its base) to give the screen life; the
// soil tile and shadow stay put.
class _SwayingFlower extends StatefulWidget {
  const _SwayingFlower();

  @override
  State<_SwayingFlower> createState() => _SwayingFlowerState();
}

class _SwayingFlowerState extends State<_SwayingFlower>
    with SingleTickerProviderStateMixin {
  // ±2.6° ping-pong, matching the garden's plant sway feel.
  static const double _maxRad = 2.6 * math.pi / 180;

  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  late final Animation<double> _angle = Tween<double>(
    begin: -_maxRad,
    end: _maxRad,
  ).animate(CurvedAnimation(parent: _sway, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) return;
    if (!_sway.isAnimating) _sway.repeat(reverse: true);
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 14,
            child: SvgPicture.asset(
              'assets/gardent-view/Ellipse.svg',
              width: 220,
            ),
          ),
          Positioned(
            bottom: 44,
            child: SvgPicture.asset(
              'assets/gardent-view/tiles-turf.svg',
              width: 132,
            ),
          ),
          // The flower, pivoting about its base inside the soil.
          Positioned(
            bottom: 78,
            child: AnimatedBuilder(
              animation: _angle,
              builder: (_, child) => Transform.rotate(
                angle: _angle.value,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
              child: SvgPicture.asset(
                'assets/gardent-view/plants-grammer-bloom.svg',
                height: 150,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
