// Garden ("My Garden") — API-driven progress map, ported to the Figma design
// (iPhone 16 Plus garden frame): a sky → rolling-meadow backdrop with a level
// badge, sun and clouds, then a vertical run of isometric plots (one per unit
// step). Each plot = turf-shadow ellipse + tile + bush + plants that grow from
// the live GET /users/me/garden data. A fixed "Let's Talk" bar sits at the
// bottom. Tapping a plant opens its Skill Sheet; tapping a plot/label opens the
// Unit Sheet.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../route_observer.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/garden.dart';
import '../../providers/chat_provider.dart';
import '../../providers/garden_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/audio_service.dart';
import '../../services/sounds.dart';
import 'widgets/garden_dialogs.dart';
import 'widgets/spotlight_overlay.dart';
import 'widgets/zoe_mascot.dart';

// Dawn Garden values from docs/Garden Themes - Figma Values.md.
const Color _dawnSkyTop = Color(0xFFFFE3D0);
const Color _dawnSkyMid = Color(0xFFF6C9E0);
const Color _dawnSkyBottom = Color(0xFFE4E8FA);
const Color _dawnHillTop = Color(0xFFE8F0B8);
const Color _dawnHillMid = Color(0xFFA8D888);
const Color _dawnHillBottom = Color(0xFF5C9A48);
const List<Color> _dawnSky = [_dawnSkyTop, _dawnSkyMid, _dawnSkyBottom];
const List<Color> _dawnHill = [_dawnHillTop, _dawnHillMid, _dawnHillBottom];
const List<double> _gardenStops = [0, 0.55, 1];

const double _designWidth = 430;
const double _pinnedSkyHeight = 176;
const double _scrollStartY = 210;
const double _ctaFadeHeight = 84;
const double _unitRowH = 345;
const double _plotW = 287.32;
const double _plotH = 143;
const double _tileW = 105;
const double _tileH = 80;
// Slot the flower art sits in; enlarged 30% alongside the plant heights below.
const double _plantSlotW = 72.8; // 56 × 1.3
const double _ellipseW = 287.32;
const double _ellipseH = 130;

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
  bool _soundOn = true;
  Timer? _welcomeTimer;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioProvider);
    _soundOn = _audio.musicEnabled && _audio.sfxEnabled;
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

  Future<void> _toggleSound() async {
    final next = !_soundOn;
    setState(() => _soundOn = next);
    await _audio.setSfxEnabled(next);
    await _audio.setMusicEnabled(next);
    if (next) {
      await _audio.playMusic(Sounds.gardenMusic);
    } else {
      await _audio.stopMusic();
    }
  }

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
      color: _dawnHillBottom,
      child: gardenAsync.when(
        data: (data) => _GardenView(
          data: data,
          soundOn: _soundOn,
          onToggleSound: _toggleSound,
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
          colors: [_dawnSkyTop, _dawnHillMid],
        ),
      ),
      child: child,
    );
  }
}

class _GardenView extends ConsumerWidget {
  final GardenData data;
  final bool soundOn;
  final VoidCallback onToggleSound;
  const _GardenView({
    required this.data,
    required this.soundOn,
    required this.onToggleSound,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final childName =
        ref.watch(onboardingProvider).valueOrNull?.name?.trim() ?? '';
    final titleName = childName.isEmpty ? 'Narendra' : childName;
    final levelName = data.theme.trim().isNotEmpty
        ? data.theme.trim()
        : (data.levelLabel.trim().isNotEmpty
              ? data.levelLabel.trim()
              : 'Dawn Glade');

    return Stack(
      children: [
        const Positioned.fill(child: _DawnGardenBackdrop()),
        Positioned.fill(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: media.padding.top + _scrollStartY,
              bottom: media.padding.bottom + _ctaFadeHeight + 32,
            ),
            child: data.steps.isEmpty
                ? const _EmptyGardenState()
                : Column(
                    children: [
                      for (var i = 0; i < data.steps.length; i++)
                        _GardenUnitRow(
                          data: data,
                          step: data.steps[i],
                          index: i,
                        ),
                    ],
                  ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: _PinnedGardenHeader(
            levelName: levelName,
            gardenTitle: "$titleName's Garden",
            soundOn: soundOn,
            onBack: () => Navigator.of(context).maybePop(),
            onToggleSound: onToggleSound,
          ),
        ),
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
    );
  }
}

// ── Fixed Dawn sky, header and scrolling units ───────────────────────────────

class _DawnGardenBackdrop extends StatelessWidget {
  const _DawnGardenBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _DawnBackdropPainter()),
        Positioned(
          top: MediaQuery.of(context).padding.top + 122,
          left: -12,
          child: const _Cloud(width: 78),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 120,
          right: -19,
          child: const _Cloud(width: 78),
        ),
      ],
    );
  }
}

class _DawnBackdropPainter extends CustomPainter {
  const _DawnBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final skyH = math.min(h, _pinnedSkyHeight);
    final hillStart = math.max(0.0, skyH - 7);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, skyH + 18),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _dawnSky,
          stops: _gardenStops,
        ).createShader(Rect.fromLTWH(0, 0, w, skyH)),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, hillStart, w, h - hillStart),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _dawnHill,
          stops: _gardenStops,
        ).createShader(Rect.fromLTWH(0, hillStart, w, h - hillStart)),
    );

    final backHill = Path()
      ..moveTo(0, skyH + 40)
      ..quadraticBezierTo(w * 0.38, skyH - 18, w, skyH + 28)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      backHill,
      Paint()..color = _dawnHill.first.withValues(alpha: 0.64),
    );
  }

  @override
  bool shouldRepaint(_DawnBackdropPainter oldDelegate) => false;
}

class _PinnedGardenHeader extends StatelessWidget {
  final String levelName;
  final String gardenTitle;
  final bool soundOn;
  final VoidCallback onBack;
  final VoidCallback onToggleSound;

  const _PinnedGardenHeader({
    required this.levelName,
    required this.gardenTitle,
    required this.soundOn,
    required this.onBack,
    required this.onToggleSound,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: top + _pinnedSkyHeight,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _PinnedSkyPainter()),
          ),
          Positioned(top: top + 122, left: -12, child: const _Cloud(width: 78)),
          Positioned(
            top: top + 120,
            right: -19,
            child: const _Cloud(width: 78),
          ),
          Positioned(
            left: 24,
            right: 20,
            top: top + 16,
            child: Column(
              children: [
                Row(
                  children: [
                    _HeaderCircleButton(
                      onTap: onBack,
                      icon: Icons.arrow_back_rounded,
                      fill: Colors.transparent,
                      iconColor: EllaColors.greenDeep,
                      border: EllaColors.greenDeep,
                    ),
                    const SizedBox(width: 16),
                    _LevelSelectorPill(levelName: levelName),
                    const Spacer(),
                    _HeaderCircleButton(
                      onTap: onToggleSound,
                      icon: soundOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      fill: soundOn
                          ? EllaColors.berryMain
                          : EllaColors.textTertiary,
                      iconColor: EllaColors.onPrimary,
                      border: Colors.transparent,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  gardenTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EllaFonts.bricolage(
                    const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                      letterSpacing: 0,
                      color: EllaColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedSkyPainter extends CustomPainter {
  const _PinnedSkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _dawnSky,
          stops: _gardenStops,
        ).createShader(Offset.zero & size),
    );

    final hillTop = h - 56;
    final hill = Path()
      ..moveTo(0, hillTop + 14)
      ..quadraticBezierTo(w * 0.42, hillTop - 28, w, hillTop + 4)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      hill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_dawnHillTop, _dawnHillMid],
        ).createShader(Rect.fromLTWH(0, hillTop - 28, w, 84)),
    );
  }

  @override
  bool shouldRepaint(_PinnedSkyPainter oldDelegate) => false;
}

class _HeaderCircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color fill;
  final Color iconColor;
  final Color border;

  const _HeaderCircleButton({
    required this.onTap,
    required this.icon,
    required this.fill,
    required this.iconColor,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            color: border,
            width: border == Colors.transparent ? 0 : 3,
          ),
        ),
        child: Icon(icon, size: 19, color: iconColor),
      ),
    );
  }
}

class _LevelSelectorPill extends StatelessWidget {
  final String levelName;
  const _LevelSelectorPill({required this.levelName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: EllaColors.border, width: 2.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/garden/plants/Sunrise Seedbed Icon 1.svg',
            width: 24,
            height: 24,
          ),
          const SizedBox(width: 12),
          Text(
            levelName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EllaFonts.body(
              const TextStyle(
                fontSize: 16.7,
                fontWeight: FontWeight.w600,
                height: 1.6,
                color: EllaColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: EllaColors.greenDeep,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 19,
              color: EllaColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
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

class _EmptyGardenState extends StatelessWidget {
  const _EmptyGardenState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: EllaColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EllaColors.border, width: 2),
        ),
        child: Text(
          'Your garden is getting ready.',
          textAlign: TextAlign.center,
          style: EllaTextStyles.bodySemibold,
        ),
      ),
    );
  }
}

// ── One garden unit row ───────────────────────────────────────────────────────

class _GardenUnitRow extends StatelessWidget {
  final GardenData data;
  final GardenStep step;
  final int index;
  const _GardenUnitRow({
    required this.data,
    required this.step,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / _designWidth).clamp(0.86, 1.10);
        final leftInset = (constraints.maxWidth - _designWidth * scale) / 2;
        final plotOnLeft = index.isEven;
        final signW = _signWidthFor(step.name);
        final signH = _signHeightFor(step.name);
        final signX = plotOnLeft ? _designWidth - 40 - signW : 27.0;
        final signY = 23.0;
        final plotX = plotOnLeft ? 40.0 : 101.0;
        final plotY = signH > 40 ? 103.0 : (plotOnLeft ? 83.0 : 76.0);
        final fenceX = plotOnLeft ? 47.0 : 240.0;
        final fenceY = plotOnLeft ? 245.0 : 235.0;
        final grassX = plotOnLeft ? 334.0 : 56.0;
        final grassY = plotOnLeft ? plotY + 124.0 : 247.0;
        final butterflyX = plotOnLeft ? (index == 0 ? 64.0 : 108.0) : 223.0;
        final butterflyY = plotOnLeft ? plotY - 4.0 : plotY + 44.0;

        return SizedBox(
          height: _unitRowH * scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: leftInset,
                top: 0,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: _designWidth,
                    height: _unitRowH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: plotX,
                          top: plotY,
                          child: _Plot(data: data, step: step),
                        ),
                        Positioned(
                          left: signX,
                          top: signY,
                          child: _UnitSignPost(
                            name: step.name,
                            width: signW,
                            height: signH,
                            onTap: () => showUnitSheet(context, data, step),
                          ),
                        ),
                        Positioned(
                          left: signX + signW / 2 - 16,
                          top: signY - 24,
                          child: _UnitBadge(index: index, step: step),
                        ),
                        Positioned(
                          left: fenceX,
                          top: fenceY,
                          child: _FenceRun(leansRight: !plotOnLeft),
                        ),
                        Positioned(
                          left: grassX,
                          top: grassY,
                          child: const _GrassTuft(),
                        ),
                        if (step.hasGrowth || index < 4)
                          Positioned(
                            left: butterflyX,
                            top: butterflyY,
                            child: const _Butterfly(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

double _signWidthFor(String name) {
  if (name.length > 26) return 185;
  if (name.length > 16) return 177;
  return 163;
}

double _signHeightFor(String name) => name.length > 26 ? 60 : 40;

class _UnitSignPost extends StatelessWidget {
  final String name;
  final double width;
  final double height;
  final VoidCallback onTap;
  const _UnitSignPost({
    required this.name,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: withTapClick(onTap),
      child: SizedBox(
        width: width,
        height: height + 13,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 11.5, bottom: 0, child: _SignLeg(height: 13)),
            Positioned(right: 11.5, bottom: 0, child: _SignLeg(height: 13)),
            Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFC49050),
                    Color(0xFF9B6828),
                    Color(0xFFB08040),
                    Color(0xFF966828),
                    Color(0xFF8A5712),
                  ],
                  stops: [0, 0.28, 0.55, 0.78, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.22),
                    offset: const Offset(0, 2),
                    blurRadius: 3,
                    blurStyle: BlurStyle.inner,
                  ),
                  BoxShadow(
                    color: const Color(0xFF3A2010).withValues(alpha: 0.2),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                    blurStyle: BlurStyle.inner,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const _NailDot(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: height > 40 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: EllaFonts.body(
                        const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _NailDot(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignLeg extends StatelessWidget {
  final double height;
  const _SignLeg({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF79502C),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
    );
  }
}

class _NailDot extends StatelessWidget {
  const _NailDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFF3A2010),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.2),
            offset: const Offset(0.5, 0.5),
            blurRadius: 0.5,
          ),
        ],
      ),
    );
  }
}

class _UnitBadge extends StatelessWidget {
  final int index;
  final GardenStep step;
  const _UnitBadge({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    final icon = switch (index % 5) {
      0 => Icons.card_giftcard_rounded,
      1 => Icons.chat_bubble_outline_rounded,
      2 => Icons.thumb_up_alt_outlined,
      3 => Icons.check_circle_outline_rounded,
      _ => Icons.travel_explore_rounded,
    };
    final color = switch (index % 5) {
      0 => EllaColors.error,
      1 => EllaColors.info,
      2 => EllaColors.greenDark,
      3 => EllaColors.berryMain,
      _ => EllaColors.infoDark,
    };
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: EllaColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC49050), width: 2),
      ),
      child: Icon(
        icon,
        size: 16,
        color: step.isCompleted ? EllaColors.greenDark : color,
      ),
    );
  }
}

class _FenceRun extends StatelessWidget {
  final bool leansRight;
  const _FenceRun({required this.leansRight});

  @override
  Widget build(BuildContext context) {
    final positions = leansRight
        ? const [Offset(0, 30), Offset(48, 21), Offset(95, 0)]
        : const [Offset(0, 0), Offset(47, 12), Offset(99, 24)];
    return SizedBox(
      width: 139,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final offset in positions)
            Positioned(
              left: offset.dx,
              top: offset.dy,
              child: SvgPicture.asset(
                'assets/garden/props/fence-segment.svg',
                width: 40,
                height: 24,
              ),
            ),
        ],
      ),
    );
  }
}

class _GrassTuft extends StatelessWidget {
  const _GrassTuft();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/garden/ambient/grass-tuft.svg',
      width: 24,
      height: 30,
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
      ..sort((a, b) => tileSpots[a].top.compareTo(tileSpots[b].top));

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
            top: 9,
            left: 0,
            child: SvgPicture.asset(
              'assets/gardent-view/Ellipse.svg',
              width: _ellipseW,
              height: _ellipseH,
            ),
          ),
          // Bush resting inside the turf-shadow ellipse (front-left).
          Positioned(
            top: 66,
            left: 20,
            child: SvgPicture.asset(
              'assets/gardent-view/bush.svg',
              width: 34.6,
            ),
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
          if (hasBloom) const Positioned(top: 0, left: 24, child: _Butterfly()),
        ],
      ),
    );
  }
}

class _TileSpot {
  final double left;
  final double top;
  const _TileSpot({required this.left, required this.top});
}

List<_TileSpot> _tileSpotsFor(int count) {
  if (count <= 0) return const [];
  const figmaSpots = [
    _TileSpot(left: 118, top: 9),
    _TileSpot(left: 70, top: 33),
    _TileSpot(left: 167, top: 34),
    _TileSpot(left: 118, top: 58),
  ];
  if (count <= figmaSpots.length) {
    if (count == 1) return const [_TileSpot(left: 118, top: 33)];
    if (count == 2) {
      return const [
        _TileSpot(left: 70, top: 33),
        _TileSpot(left: 167, top: 34),
      ];
    }
    return figmaSpots.take(count).toList(growable: false);
  }

  const isoHalfW = 45.0;
  const isoHalfH = 22.5;
  final centerLeft = (_plotW - _tileW) / 2;
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
          left: centerLeft + (ci - cj) * isoHalfW,
          top: 20 + (ci + cj) * isoHalfH,
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
      top: spot.top,
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
      top: spot.top + _tileH * 0.72 - _plantHeightFor(skill),
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

double _plantHeightFor(GardenSkill skill) => switch (skill.sightings) {
  <= 0 => 0,
  1 => 62.4,
  2 => 88.4,
  _ => 114.4,
};

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
    final height = _plantHeightFor(widget.skill);
    final asset = switch (widget.skill.sightings) {
      <= 0 => '',
      1 => widget.skill.strand.seedlingAsset,
      2 => widget.skill.strand.youngAsset,
      _ => widget.skill.strand.bloomAsset,
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

class _ButterflyState extends State<_Butterfly> with TickerProviderStateMixin {
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
          tween: Tween(
            begin: pts[i],
            end: pts[i + 1],
          ).chain(CurveTween(curve: Curves.easeInOut)),
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
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: _ctaFadeHeight + bottom,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                EllaColors.surface.withValues(alpha: 0),
                EllaColors.surface.withValues(alpha: 0.88),
                EllaColors.surface,
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom + 6),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ZoeMascot(
                    mode: ZoeMascotMode.listening,
                    size: 64,
                    reducedMotion: MediaQuery.of(context).disableAnimations,
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: withTapClick(onTalk),
                    child: Container(
                      width: 154,
                      height: 48,
                      decoration: BoxDecoration(
                        color: EllaColors.berryMain,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: EllaColors.berryDeep,
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: EllaColors.berryDeep,
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.record_voice_over_rounded,
                            size: 16,
                            color: EllaColors.onPrimary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Let's Talk",
                            style: EllaFonts.body(
                              const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.6,
                                color: EllaColors.onPrimary,
                              ),
                            ),
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
    );
  }
}
