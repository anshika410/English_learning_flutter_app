// Placement garden — the "Sunrise Seedbed" scene shown after the placement
// conversation ends (Figma "Placement Flow": Placement Garden → Animate to Full
// Bloom → shift to the new garden), replacing the old PlacementCompleteScreen.
//
// The screen resolves its branch reactively from placementProvider.levelAssigned
// (set after the post-completion memory refresh, so it never races the 1600ms
// advance from PlacementScreen):
//   • Level assigned → the sprout blooms into a flower, a spotlight highlights
//     it with the "Your flower is blooming!" card for ~2s, then the screen swaps
//     to the real GardenScreen with its first-time welcome.
//   • No level (null in /memory) → the sprout stays; "Let's Talk" pops back to
//     the root, where RootGate still shows the PlacementIntroScreen.
//
// Also reachable in [browse] mode from the Placement Home garden shortcut: the
// settled sprout garden right away, with back + "Let's Talk" returning to the
// intro.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/placement_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/audio_service.dart';
import '../../services/sounds.dart';
import 'garden_screen.dart';
import 'home_screen.dart' show kHomeChildName;
import 'widgets/ella_primary_button.dart';
import 'widgets/garden_sky_background.dart';
import 'widgets/garden_sound_button.dart';
import 'widgets/placement_garden_header.dart';
import 'widgets/spotlight_overlay.dart';
import 'widgets/zoe_mascot.dart';

const String _kVoiceIcon = 'assets/homescreen/new/UserSound.svg';
const String _kFenceIcon = 'assets/garden/props/fence-segment.svg';

enum _Phase {
  /// Sprout growing / waiting for the level to resolve.
  sprout,

  /// Level assigned: the sprout has bloomed into the flower.
  bloom,

  /// Spotlight + "blooming" card over the flower, before the garden swap.
  spotlight,

  /// No level: the sprout stays and "Let's Talk" returns to the intro.
  settled,
}

class PlacementGardenScreen extends ConsumerStatefulWidget {
  /// True when opened as a plain view (Placement Home garden shortcut): shows
  /// the settled sprout immediately, without waiting on placement state.
  final bool browse;

  const PlacementGardenScreen({super.key, this.browse = false});

  @override
  ConsumerState<PlacementGardenScreen> createState() =>
      _PlacementGardenScreenState();
}

class _PlacementGardenScreenState extends ConsumerState<PlacementGardenScreen> {
  _Phase _phase = _Phase.sprout;
  bool _resolved = false;
  final List<Timer> _timers = [];

  // Set just before we pushReplacement into GardenScreen (bloom branch). That
  // screen's initState starts the SAME ambient loop before our dispose runs, so
  // we must NOT stop it on the way out or the garden would fall silent.
  bool _handingOffToGarden = false;

  // Captured in initState so dispose() never reads `ref` while deactivating —
  // matching GardenScreen, so the ambient loop reliably stops on leave.
  late final AudioInterface _audio;

  @override
  void initState() {
    super.initState();
    // The placement garden is a garden screen: play the same ambient loop, and
    // stop it in dispose() when the child leaves (or we swap to GardenScreen).
    _audio = ref.read(audioProvider);
    _audio.playMusic(Sounds.gardenMusic);
    if (widget.browse) {
      _phase = _Phase.settled;
      return;
    }
    // The branch may already be known when we arrive (the memory refresh
    // usually lands before PlacementScreen's 1600ms advance).
    final known = ref.read(placementProvider).levelAssigned;
    if (known != null) {
      _after(400, () => _onResolved(known));
    } else {
      // Safety net: if the refresh hangs (offline), fall back to the level the
      // turn itself returned so the child is never parked on a waiting sprout.
      _after(6000, () {
        if (_resolved) return;
        _onResolved(ref.read(placementProvider).result?.level != null);
      });
    }
  }

  void _after(int ms, VoidCallback fn) {
    _timers.add(
      Timer(Duration(milliseconds: ms), () {
        if (mounted) fn();
      }),
    );
  }

  void _onResolved(bool levelAssigned) {
    if (_resolved) return;
    _resolved = true;
    if (!levelAssigned) {
      setState(() => _phase = _Phase.settled);
      return;
    }
    final reduced = MediaQuery.of(context).disableAnimations;
    // Let the sprout finish growing in, bloom, spotlight the flower for ~2s,
    // then hand over to the real garden.
    _after(reduced ? 0 : 1200, () => setState(() => _phase = _Phase.bloom));
    _after(reduced ? 400 : 2100, () {
      setState(() => _phase = _Phase.spotlight);
    });
    _after(reduced ? 2400 : 4300, _toLevelGarden);
  }

  void _toLevelGarden() {
    if (!mounted) return;
    // GardenScreen will own the ambient loop from here — don't stop it in our
    // dispose (see [_handingOffToGarden]).
    _handingOffToGarden = true;
    // pushReplacement keeps the stack RootGate → Garden, so the garden's
    // "Let's Talk" / back land on the (now placement-aware) Home.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          backgroundColor: Colors.transparent,
          body: GardenScreen(firstTime: true),
        ),
      ),
    );
  }

  // Sprout branch: back to the root — RootGate still shows the placement
  // intro (no level was persisted), which is where the child restarts.
  void _letsTalk() => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    if (!_handingOffToGarden) _audio.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(placementProvider.select((s) => s.levelAssigned), (_, next) {
      if (next != null) _onResolved(next);
    });

    final name =
        ref.watch(onboardingProvider).valueOrNull?.name ?? kHomeChildName;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final spotlightOn = _phase == _Phase.spotlight;

    return Scaffold(
      backgroundColor: EllaColors.surfaceVariant,
      body: GardenSkyBackground(
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Dim the surroundings while the bloom spotlight is on.
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: spotlightOn ? 1 : 0,
                  duration: Duration(milliseconds: reducedMotion ? 0 : 600),
                  child: const SpotlightOverlay(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    PlacementGardenHeader(
                      name: name,
                      onBack: widget.browse
                          ? () => Navigator.of(context).maybePop()
                          : null,
                      trailing: const GardenSoundButton(size: 38),
                    ),
                    // Bloom message card — only during the spotlight beat.
                    AnimatedOpacity(
                      opacity: spotlightOn ? 1 : 0,
                      duration: Duration(milliseconds: reducedMotion ? 0 : 600),
                      child: IgnorePointer(
                        ignoring: !spotlightOn,
                        child: const Padding(
                          padding: EdgeInsets.only(top: 14),
                          child: _BloomMessageCard(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _PlantStage(
                          bloomed: _phase == _Phase.bloom ||
                              _phase == _Phase.spotlight,
                          reducedMotion: reducedMotion,
                        ),
                      ),
                    ),
                    // Fence row below the plot (Figma placement-garden frame).
                    const _FenceRow(),
                    const SizedBox(height: 16),
                    // "Let's Talk" only on the sprout (no level) branch — the
                    // bloom branch advances to the garden by itself.
                    // Small Zoe beside the compact CTA pill — the mascot is the
                    // same height as the button, per the Figma frame.
                    if (_phase == _Phase.settled)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ZoeMascot(
                            mode: ZoeMascotMode.listening,
                            size: 44,
                            reducedMotion: reducedMotion,
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 164,
                            child: EllaPrimaryButton(
                              label: "Let's Talk",
                              height: 44,
                              leading: SvgPicture.asset(
                                _kVoiceIcon,
                                width: 17,
                                height: 17,
                                colorFilter: const ColorFilter.mode(
                                  EllaColors.onPrimary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              onTap: _letsTalk,
                            ),
                          ),
                        ],
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

// The turf tile with the growing plant: the sprout pops up from its base
// (easeOutBack, like the onboarding first sprout); when [bloomed] flips true it
// crossfades into the full flower, which scales in with the garden's spring
// pop curve.
class _PlantStage extends StatefulWidget {
  final bool bloomed;
  final bool reducedMotion;

  const _PlantStage({required this.bloomed, required this.reducedMotion});

  @override
  State<_PlantStage> createState() => _PlantStageState();
}

class _PlantStageState extends State<_PlantStage>
    with TickerProviderStateMixin {
  // Spring-overshoot pop from the garden plant handoff.
  static const Cubic _popCurve = Cubic(0.34, 1.56, 0.64, 1.0);

  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _growScale = CurvedAnimation(
    parent: _grow,
    curve: Curves.easeOutBack,
  );

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _popScale = CurvedAnimation(
    parent: _pop,
    curve: _popCurve,
  );

  @override
  void initState() {
    super.initState();
    _grow.forward();
    if (widget.bloomed) _pop.value = 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) _grow.value = 1.0;
  }

  @override
  void didUpdateWidget(_PlantStage old) {
    super.didUpdateWidget(old);
    if (widget.bloomed && !old.bloomed) {
      if (widget.reducedMotion) {
        _pop.value = 1.0;
      } else {
        _pop.forward();
      }
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 260,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Warm glow pooled around the tile (matches the onboarding sprout).
          Positioned(
            bottom: -20,
            child: FadeTransition(
              opacity: _growScale,
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x8CFFF3D4),
                      Color(0x40FFF3D4),
                      Color(0x00FFF3D4),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
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
          // Sprout — grows in, fades away when the flower blooms over it.
          // Figma placement-plant exports carry their own base shadow, so they
          // sit a touch lower on the tile than the gardent-view plants.
          Positioned(
            bottom: 70,
            child: FadeTransition(
              opacity: ReverseAnimation(_popScale),
              child: ScaleTransition(
                scale: _growScale,
                alignment: Alignment.bottomCenter,
                child: SvgPicture.asset(
                  'assets/garden/plants/placement-plant-young.svg',
                  height: 112,
                ),
              ),
            ),
          ),
          // Full bloom — springs up from the same base.
          Positioned(
            bottom: 70,
            child: ScaleTransition(
              scale: _popScale,
              alignment: Alignment.bottomCenter,
              child: SvgPicture.asset(
                'assets/garden/plants/placement-plant-bloom.svg',
                height: 152,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A run of fence segments under the plot, matching the Figma frame.
class _FenceRow extends StatelessWidget {
  const _FenceRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SvgPicture.asset(_kFenceIcon, height: 26),
          ),
      ],
    );
  }
}
