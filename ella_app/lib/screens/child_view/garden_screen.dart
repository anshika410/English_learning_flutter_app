// Garden ("My Garden") — API-driven progress map, ported to the Figma design
// (iPhone 16 Plus garden frame): a sky → rolling-meadow backdrop with a level
// badge, sun and clouds, then a vertical run of isometric plots (one per unit
// step). Each plot = turf-shadow ellipse + tile + bush + plants that grow from
// the live GET /users/me/garden data. A fixed "Let's Talk" bar sits at the
// bottom. Tapping a plant opens its Skill Sheet; tapping a plot/label opens the
// Unit Sheet.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../route_observer.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/garden.dart';
import '../../providers/chat_provider.dart';
import '../../providers/garden_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/audio_service.dart';
import '../../services/sounds.dart';
import 'widgets/garden_dialogs.dart';
import 'widgets/garden_sound_button.dart';
import 'widgets/spotlight_overlay.dart';
import 'widgets/zoe_mascot.dart';

// Botanical Berry garden palette: environment sky easing into the garden-field
// ground ramp (fieldLight → fieldMain → fieldDark).
const Color _skyTop = EllaColors.environmentLight;
const Color _skyBottom = EllaColors.environmentMain;
const Color _hillBack = EllaColors.fieldLight;
const Color _meadowTop = EllaColors.fieldMain;
const Color _meadowBottom = EllaColors.fieldDark;

const double _skyHeight = 188;
const double _plotW = 220;
const double _plotH = 190;
const double _tileW = 98.4; // 82 × 1.2 (tiles enlarged 20%)
const double _tileH = _tileW / 105 * 80;
// Slot the flower art sits in; enlarged 30% alongside the plant heights below.
const double _plantSlotW = 72.8; // 56 × 1.3
// Half-extents of a tile's isometric top-face diamond (the tiles.svg top face
// runs x:7.5→97.5, y:7.5→52.5 in its 105-wide viewBox). Tiles must step by
// exactly these amounts to tessellate edge-to-edge without overlapping.
const double _isoHalfW = _tileW / 105 * 45;
const double _isoHalfH = _tileW / 105 * 22.5;
const double _ellipseW = 204;
const double _ellipseH = _ellipseW / 252 * 119;

// First-time welcome copy (Figma "Shift to new garden and nudge to start
// talking") — shown under a spotlight when arriving from placement.
const String _kWelcomeText =
    'Welcome to your garden! 💗\nEach time we talk, a new plant grows here. '
    'Ready?';

class GardenScreen extends ConsumerStatefulWidget {
  final VoidCallback? onConversationEnded;

  /// True when arriving from the placement bloom: shows a spotlight + Zoe's
  /// "Welcome to your garden" nudge for a few seconds before the normal garden.
  final bool firstTime;

  const GardenScreen({
    super.key,
    this.onConversationEnded,
    this.firstTime = false,
  });

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> with RouteAware {
  // Last-seen sightings per skill id, so we can detect when a skill grows
  // (sightings increase) after a session and play the new-sprout cue once.
  // Seeded from the first garden payload — no sound on initial load.
  Map<String, int> _lastSightings = {};

  // Captured in initState so dispose() never reads `ref` (unreliable while the
  // element is deactivating) — otherwise the stop-on-leave can silently fail.
  late final AudioInterface _audio;

  // First-time welcome spotlight (firstTime only): on while Zoe greets, then
  // fades out leaving the normal garden.
  bool _welcomeOn = false;
  Timer? _welcomeTimer;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioProvider);
    // Start on every mount so the loop is audible each time the garden opens
    // (not just the first time).
    _startMusic();
    if (widget.firstTime) {
      _welcomeOn = true;
      // Best-effort: greet aloud while the spotlight is up.
      try {
        ref.read(ttsProvider).speak(_kWelcomeText.replaceAll('💗', ''));
      } catch (_) {}
      _welcomeTimer = Timer(const Duration(milliseconds: 2800), () {
        if (mounted) setState(() => _welcomeOn = false);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe as RouteAware so we can react when another screen is pushed on
    // top of / popped back to the garden. Subscribing is idempotent.
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  void _startMusic() => _audio.playMusic(Sounds.gardenMusic);
  void _stopMusic() => _audio.stopMusic();

  // The garden loop plays only while this screen is the visible, top-most route.
  // dispose() alone isn't enough: pushing Session/Profile on top doesn't dispose
  // the garden, so we stop the loop on didPushNext and resume it on didPopNext.
  @override
  void didPopNext() => _startMusic();

  @override
  void didPushNext() => _stopMusic();

  /// Records the current sightings and returns true if any skill grew since the
  /// previous payload. Returns false on the first payload (baseline only).
  bool _registerAndDetectGrowth(GardenData data) {
    final next = <String, int>{};
    for (final step in data.steps) {
      for (final skill in step.skills) {
        next[skill.id] = skill.sightings;
      }
    }
    var grew = false;
    if (_lastSightings.isNotEmpty) {
      for (final entry in next.entries) {
        if (entry.value > (_lastSightings[entry.key] ?? 0)) {
          grew = true;
          break;
        }
      }
    }
    _lastSightings = next;
    return grew;
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    appRouteObserver.unsubscribe(this);
    _stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Refetch the garden the instant a chat ends. endChat() sets sessionEnded
    // only after the server has merged the new state, so this pulls fresh
    // growth without the child having to leave and re-open the tab.
    ref.listen<AsyncValue<ChatState>>(chatProvider, (prev, next) {
      final wasEnded = prev?.valueOrNull?.sessionEnded ?? false;
      final isEnded = next.valueOrNull?.sessionEnded ?? false;
      if (isEnded && !wasEnded) ref.invalidate(gardenProvider);
    });
    // When refreshed garden data shows a skill has grown, play the new-sprout
    // cue. Baseline is set silently on the first payload.
    ref.listen<AsyncValue<GardenData>>(gardenProvider, (prev, next) {
      final data = next.valueOrNull;
      if (data == null) return;
      if (_registerAndDetectGrowth(data)) {
        ref.read(audioProvider).playSfx(Sounds.newSprout);
      }
    });
    final gardenAsync = ref.watch(gardenProvider);
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final garden = Container(
      color: _meadowBottom,
      child: gardenAsync.when(
        data: (data) => _GardenView(
          data: data,
          onConversationEnded: widget.onConversationEnded,
        ),
        loading: () => const _SkyScaffold(
          child: Center(
            child: CircularProgressIndicator(color: EllaColors.berryDark),
          ),
        ),
        error: (e, _) => _SkyScaffold(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not load your garden',
                  style: TextStyle(
                    color: EllaColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: withTapClick(() => ref.invalidate(gardenProvider)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!widget.firstTime) return garden;

    // First-time arrival from placement: spotlight + Zoe's welcome over the
    // garden for a few seconds, then the normal garden remains.
    return Stack(
      fit: StackFit.expand,
      children: [
        garden,
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _welcomeOn ? 1 : 0,
            duration: Duration(milliseconds: reducedMotion ? 0 : 600),
            child: const SpotlightOverlay(center: Alignment(0, 0)),
          ),
        ),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _welcomeOn ? 1 : 0,
            duration: Duration(milliseconds: reducedMotion ? 0 : 600),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ZoeMascot(
                      mode: ZoeMascotMode.listening,
                      size: 72,
                      reducedMotion: reducedMotion,
                    ),
                    const SizedBox(height: 2),
                    const _WelcomeBubble(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeBubble extends StatelessWidget {
  const _WelcomeBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EllaColors.info, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        _kWelcomeText,
        style: EllaTextStyles.zoeVoice.copyWith(height: 1.4),
      ),
    );
  }
}

class _SkyScaffold extends StatelessWidget {
  final Widget child;
  const _SkyScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _meadowTop],
        ),
      ),
      child: child,
    );
  }
}

class _GardenView extends ConsumerWidget {
  final GardenData data;
  final VoidCallback? onConversationEnded;
  const _GardenView({required this.data, required this.onConversationEnded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                _SkyHills(level: data.level, theme: data.theme),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_meadowTop, _meadowBottom],
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < data.steps.length; i++)
                        _PlotRow(
                          data: data,
                          step: data.steps[i],
                          plotOnLeft: i.isEven,
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Mute/unmute the garden ambient loop — fixed top-right control so it
          // stays put while the plots scroll.
          const Positioned(top: 16, right: 20, child: GardenSoundButton()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _LetsTalkBar(
              // The button returns to Home, where the child picks a topic and
              // starts a session (the garden no longer starts one directly).
              onTalk: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sky + rolling hills ───────────────────────────────────────────────────────

class _SkyHills extends StatelessWidget {
  final String level;
  final String theme;
  const _SkyHills({required this.level, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _skyHeight,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_skyTop, _skyBottom],
                ),
              ),
            ),
          ),
          Positioned(
            top: -12,
            right: -8,
            child: SvgPicture.asset(
              'assets/gardent-view/sun.svg',
              width: 140,
              height: 125,
            ),
          ),
          const Positioned(top: 100, left: 16, child: _Cloud(width: 92)),
          const Positioned(top: 58, right: 22, child: _Cloud(width: 78)),
          // Rolling hills filling the bottom of the sky, blending into meadow.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 86,
            child: CustomPaint(painter: _HillsPainter()),
          ),
          // Level / theme badge — also the back control to the home screen.
          Positioned(
            top: 16,
            left: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: withTapClick(() => Navigator.of(context).maybePop()),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 10,
                  right: 16,
                  top: 9,
                  bottom: 9,
                ),
                decoration: BoxDecoration(
                  // Solid berryDark so the white label stays AA-safe (a berry
                  // gradient's light band would fail under the text).
                  color: EllaColors.berryDark,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: EllaColors.berryDeep,
                      offset: Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: EllaColors.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          level.isEmpty ? 'Your Garden' : 'Level - $level',
                          style: EllaFonts.bricolage(
                            const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: EllaColors.onPrimary,
                              height: 1.0,
                            ),
                          ),
                        ),
                        if (theme.isNotEmpty)
                          Text(
                            theme,
                            style: EllaFonts.bricolage(
                              TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: EllaColors.onPrimary.withValues(
                                  alpha: 0.85,
                                ),
                                height: 1.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HillsPainter extends CustomPainter {
  const _HillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back hill (lighter).
    final back = Paint()..color = _hillBack;
    final p1 = Path()
      ..moveTo(0, h * 0.42)
      ..quadraticBezierTo(w * 0.25, h * 0.18, w * 0.5, h * 0.40)
      ..quadraticBezierTo(w * 0.78, h * 0.64, w, h * 0.34)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p1, back);

    // Front hill (meadow colour — seamless with the meadow container below).
    final front = Paint()..color = _meadowTop;
    final p2 = Path()
      ..moveTo(0, h * 0.66)
      ..quadraticBezierTo(w * 0.30, h * 0.46, w * 0.58, h * 0.66)
      ..quadraticBezierTo(w * 0.82, h * 0.82, w, h * 0.60)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p2, front);
  }

  @override
  bool shouldRepaint(_HillsPainter oldDelegate) => false;
}

class _Cloud extends StatelessWidget {
  final double width;
  const _Cloud({required this.width});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/gardent-view/clouds-weather.svg',
      width: width,
    );
  }
}

// ── One plot + its label ──────────────────────────────────────────────────────

class _PlotRow extends StatelessWidget {
  final GardenData data;
  final GardenStep step;
  final bool plotOnLeft;
  const _PlotRow({
    required this.data,
    required this.step,
    required this.plotOnLeft,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _plotH,
      child: Stack(
        children: [
          Align(
            alignment: plotOnLeft
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                left: plotOnLeft ? 12 : 0,
                right: plotOnLeft ? 0 : 12,
              ),
              child: _Plot(data: data, step: step),
            ),
          ),
          Positioned(
            top: 16,
            left: plotOnLeft ? null : 18,
            right: plotOnLeft ? 18 : null,
            child: _UnitLabel(
              name: step.name,
              onTap: () => showUnitSheet(context, data, step),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitLabel extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _UnitLabel({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: withTapClick(onTap),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: EllaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EllaColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          name,
          style: EllaFonts.bricolage(
            const TextStyle(
              fontSize: 13,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: EllaColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Plot: turf-shadow ellipse + tile + bush + plants + butterfly ──────────────

class _Plot extends StatelessWidget {
  final GardenData data;
  final GardenStep step;
  const _Plot({required this.data, required this.step});

  @override
  Widget build(BuildContext context) {
    final skills = step.skills;
    final tileSpots = _tileSpotsFor(skills.length);
    // Growth is driven purely by sightings: 0 → bare tile, 1 → seedling,
    // 2 → young, ≥3 → bloom. A butterfly visits once anything has bloomed.
    final hasBloom = step.skills.any((s) => s.sightings >= 3);

    // Paint back-to-front (higher = further back) so front tiles/plants overlap
    // the ones behind them correctly on the isometric lattice.
    final order = List<int>.generate(skills.length, (i) => i)
      ..sort((a, b) => tileSpots[b].bottom.compareTo(tileSpots[a].bottom));

    // Per-plant sway stagger: delay = (gridX + gridY) × 400ms, matching the
    // grove animation handoff. Mirrors the lattice layout in _tileSpotsFor.
    final cols = math.max(1, math.sqrt(skills.length).ceil());

    return SizedBox(
      width: _plotW,
      height: _plotH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Turf shadow disc.
          Positioned(
            bottom: 6,
            left: (_plotW - _ellipseW) / 2,
            child: SvgPicture.asset(
              'assets/gardent-view/Ellipse.svg',
              width: _ellipseW,
              height: _ellipseH,
            ),
          ),
          // Bush resting inside the turf-shadow ellipse (front-left).
          Positioned(
            bottom: 30,
            left: 32,
            child: SvgPicture.asset('assets/gardent-view/bush.svg', width: 26),
          ),
          for (final i in order)
            _SkillTile(
              skill: skills[i],
              spot: tileSpots[i],
              onTap: () => showSkillSheet(context, step, skills[i]),
            ),
          for (final i in order)
            if (skills[i].sightings >= 1)
              _SkillPlant(
                skill: skills[i],
                spot: tileSpots[i],
                swayDelayMs: ((i % cols) + (i ~/ cols)) * 400,
                onTap: () => showSkillSheet(context, step, skills[i]),
              ),
          if (hasBloom)
            const Positioned(bottom: 106, left: 24, child: _Butterfly()),
        ],
      ),
    );
  }
}

class _TileSpot {
  final double left;
  final double bottom;
  const _TileSpot({required this.left, required this.bottom});
}

List<_TileSpot> _tileSpotsFor(int count) {
  if (count <= 0) return const [];
  final centerLeft = (_plotW - _tileW) / 2;
  const baseBottom = 40.0;

  // Place tiles on a true isometric lattice: a compact, near-square block of
  // grid cells centred on the plot. Stepping by the diamond half-extents makes
  // neighbouring top faces share an edge, so the plot reads as one solid patch
  // instead of overlapping tiles.
  final cols = math.max(1, math.sqrt(count).ceil());
  final rows = (count / cols).ceil();
  return [
    for (var k = 0; k < count; k++)
      () {
        final gi = k % cols;
        final gj = k ~/ cols;
        final ci = gi - (cols - 1) / 2;
        final cj = gj - (rows - 1) / 2;
        return _TileSpot(
          left: centerLeft + (ci - cj) * _isoHalfW,
          bottom: baseBottom - (ci + cj) * _isoHalfH,
        );
      }(),
  ];
}

class _SkillTile extends StatelessWidget {
  final GardenSkill skill;
  final _TileSpot spot;
  final VoidCallback onTap;
  const _SkillTile({
    required this.skill,
    required this.spot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // No sightings yet → plain (normal) tile; once seen → tilled turf tile.
    final tileAsset = skill.sightings == 0
        ? 'assets/gardent-view/tiles.svg'
        : 'assets/gardent-view/tiles-turf.svg';

    return Positioned(
      bottom: spot.bottom,
      left: spot.left,
      child: GestureDetector(
        onTap: withTapClick(onTap),
        behavior: HitTestBehavior.translucent,
        child: SvgPicture.asset(tileAsset, width: _tileW, height: _tileH),
      ),
    );
  }
}

class _SkillPlant extends StatelessWidget {
  final GardenSkill skill;
  final _TileSpot spot;
  final int swayDelayMs;
  final VoidCallback onTap;
  const _SkillPlant({
    required this.skill,
    required this.spot,
    required this.swayDelayMs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: spot.bottom + _tileH * 0.50,
      left: spot.left + _tileW / 2 - _plantSlotW / 2,
      child: SizedBox(
        width: _plantSlotW,
        child: Center(
          child: _Plant(skill: skill, swayDelayMs: swayDelayMs, onTap: onTap),
        ),
      ),
    );
  }
}

// Spring-overshoot curve from the grove handoff: cubic-bezier(0.34,1.56,0.64,1).
// Scales past 1.0 before settling, giving the plant a satisfying "pop".
const Cubic _popCurve = Cubic(0.34, 1.56, 0.64, 1.0);

// Idle plant sway: rotation ±2.2° about the bottom-centre, 3600ms ping-pong.
const double _swayMaxRad = 2.2 * math.pi / 180;

class _Plant extends StatefulWidget {
  final GardenSkill skill;
  final int swayDelayMs;
  final VoidCallback onTap;
  const _Plant({
    required this.skill,
    required this.swayDelayMs,
    required this.onTap,
  });

  @override
  State<_Plant> createState() => _PlantState();
}

class _PlantState extends State<_Plant> with TickerProviderStateMixin {
  // Idle sway loop (1a) and one-shot pop-in (2a) from the grove handoff.
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late final Animation<double> _swayAngle = Tween<double>(
    begin: -_swayMaxRad,
    end: _swayMaxRad,
  ).animate(CurvedAnimation(parent: _sway, curve: Curves.easeInOut));

  late final Animation<double> _popScale = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _pop, curve: _popCurve));

  bool _started = false;

  void _start() {
    if (_started) return;
    _started = true;
    // Pop the plant in, then begin the staggered sway loop once it settles.
    _pop.forward();
    Future.delayed(Duration(milliseconds: widget.swayDelayMs), () {
      if (mounted) _sway.repeat(reverse: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect reduced-motion: hold everything at the final resting state.
    if (MediaQuery.of(context).disableAnimations) {
      _pop.value = 1.0;
      return;
    }
    _start();
  }

  @override
  void dispose() {
    _sway.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Growth stage follows sightings: 1 → seedling, 2 → young, ≥3 → bloom.
    // Heights enlarged 30% (48/68/88 → 62.4/88.4/114.4).
    final (asset, height) = switch (widget.skill.sightings) {
      <= 0 => ('', 0.0),
      1 => (widget.skill.strand.seedlingAsset, 62.4),
      2 => (widget.skill.strand.youngAsset, 88.4),
      _ => (widget.skill.strand.bloomAsset, 114.4),
    };
    if (asset.isEmpty) return const SizedBox.shrink();

    final art = GestureDetector(
      onTap: withTapClick(widget.onTap),
      behavior: HitTestBehavior.opaque,
      child: SvgPicture.asset(asset, height: height, fit: BoxFit.contain),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_sway, _pop]),
      // Sway rotates and pop scales about the bottom-centre (the plant's base),
      // so the stem pivots in the soil instead of drifting off its tile.
      builder: (_, child) => Transform.rotate(
        angle: _swayAngle.value,
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scale: _popScale.value,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
      child: art,
    );
  }
}

class _Butterfly extends StatefulWidget {
  const _Butterfly();
  @override
  State<_Butterfly> createState() => _ButterflyState();
}

class _ButterflyState extends State<_Butterfly>
    with TickerProviderStateMixin {
  // Float path (1c): 6500ms looping drift through the handoff's four waypoints.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6500),
  );
  // Wing flap (1b): 500ms ping-pong scaleX 1.0 ↔ 0.55.
  late final AnimationController _flap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  late final Animation<double> _floatX = _seq(const [0, 10, -6, -12, 0]);
  late final Animation<double> _floatY = _seq(const [0, -12, -22, -8, 0]);

  late final Animation<double> _flapScale = Tween<double>(
    begin: 1.0,
    end: 0.55,
  ).animate(CurvedAnimation(parent: _flap, curve: Curves.easeInOut));

  // Builds an easeInOut TweenSequence stepping through [pts] in equal segments.
  Animation<double> _seq(List<double> pts) {
    return TweenSequence<double>([
      for (var i = 0; i < pts.length - 1; i++)
        TweenSequenceItem(
          tween: Tween(begin: pts[i], end: pts[i + 1])
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 25,
        ),
    ]).animate(_float);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) return;
    if (!_float.isAnimating) _float.repeat();
    if (!_flap.isAnimating) _flap.repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    _flap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_float, _flap]),
      builder: (_, child) => Transform.translate(
        offset: Offset(_floatX.value, _floatY.value),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(_flapScale.value, 1.0, 1.0),
          child: child,
        ),
      ),
      child: SvgPicture.asset(
        'assets/gardent-view/butterfly 1.svg',
        width: 26,
        height: 26,
      ),
    );
  }
}

// ── Bottom "Let's Talk" bar ────────────────────────────────────────────────────

class _LetsTalkBar extends StatelessWidget {
  final VoidCallback onTalk;
  const _LetsTalkBar({required this.onTalk});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EllaColors.surface,
        border: const Border(
          top: BorderSide(color: EllaColors.border, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              ZoeMascot(
                mode: ZoeMascotMode.listening,
                size: 60,
                reducedMotion: MediaQuery.of(context).disableAnimations,
              ),
              const Spacer(),
              GestureDetector(
                onTap: withTapClick(onTalk),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    // Solid berryDark keeps the white label AA-safe in this
                    // compact bar button.
                    color: EllaColors.berryDark,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: EllaColors.berryDeep,
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    "Let's Talk",
                    style: EllaTextStyles.button.copyWith(
                      fontSize: 15,
                      color: EllaColors.onPrimary,
                    ),
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
