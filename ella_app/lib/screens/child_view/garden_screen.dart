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

import '../../core/ella_smooth_shape.dart';
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

// Garden values from docs/Garden Themes - Figma Values.md.
const Color _dawnSkyTop = Color(0xFFFFE3D0);
const Color _dawnSkyMid = Color(0xFFF6C9E0);
const Color _dawnSkyBottom = Color(0xFFE4E8FA);
const Color _dawnHillTop = Color(0xFFE8F0B8);
const Color _dawnHillMid = Color(0xFFA8D888);
const Color _dawnHillBottom = Color(0xFF5C9A48);
const List<Color> _dawnSky = [_dawnSkyTop, _dawnSkyMid, _dawnSkyBottom];
const List<Color> _dawnHill = [_dawnHillTop, _dawnHillMid, _dawnHillBottom];
const List<Color> _morningSky = [
  Color(0xFFEAFDFF),
  Color(0xFFD9FAFF),
  Color(0xFFF1FFF8),
];
const List<Color> _morningHill = [
  Color(0xFFD7F2C4),
  Color(0xFF8DD67C),
  Color(0xFF4E9A45),
];
const List<Color> _middaySky = [
  Color(0xFFB8E4F8),
  Color(0xFFD9FAFF),
  Color(0xFFEAFDFF),
];
const List<Color> _middayHill = [
  Color(0xFFC5E8A0),
  Color(0xFF6BC85E),
  Color(0xFF3D8438),
];
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
const double _headerSidePadding = 24;
const double _headerTopGap = 16;
const double _headerButtonSize = 30;
const double _headerButtonGap = 16;
const double _levelPillH = 43;

enum _GardenAmbientKind { butterfly, bird, bee }

class _GardenSunSpec {
  final double left;
  final double top;
  final double size;
  final Color core;
  final Color mid;
  final Color glowInner;
  final Color glowOuter;

  const _GardenSunSpec({
    required this.left,
    required this.top,
    required this.size,
    required this.core,
    required this.mid,
    required this.glowInner,
    required this.glowOuter,
  });
}

class _GardenLevelVisualSpec {
  final String code;
  final String label;
  final List<Color> sky;
  final List<Color> hill;
  final String iconAsset;
  final _GardenAmbientKind ambientKind;
  final int fenceCount;
  final bool showWildflowers;
  final double hillTop;
  final double hillLeftYOffset;
  final double hillRightYOffset;
  final _GardenSunSpec? sun;

  const _GardenLevelVisualSpec({
    required this.code,
    required this.label,
    required this.sky,
    required this.hill,
    required this.iconAsset,
    required this.ambientKind,
    required this.fenceCount,
    required this.showWildflowers,
    required this.hillTop,
    required this.hillLeftYOffset,
    required this.hillRightYOffset,
    this.sun,
  });
}

const _GardenLevelVisualSpec _dawnSpec = _GardenLevelVisualSpec(
  code: 'A0',
  label: 'Dawn Glade',
  sky: _dawnSky,
  hill: _dawnHill,
  iconAsset: 'assets/garden/plants/Sunrise Seedbed Icon 1.svg',
  ambientKind: _GardenAmbientKind.butterfly,
  fenceCount: 3,
  showWildflowers: false,
  hillTop: 176,
  hillLeftYOffset: 30,
  hillRightYOffset: 22,
);

const _GardenLevelVisualSpec _morningSpec = _GardenLevelVisualSpec(
  code: 'A1',
  label: 'Morning Meadow',
  sky: _morningSky,
  hill: _morningHill,
  iconAsset: 'assets/garden/plants/morning-meadow-icon.svg',
  ambientKind: _GardenAmbientKind.bird,
  fenceCount: 4,
  showWildflowers: true,
  hillTop: 170,
  hillLeftYOffset: 38,
  hillRightYOffset: 28,
  sun: _GardenSunSpec(
    left: 360,
    top: 160,
    size: 56,
    core: Color(0xFFFFFBEA),
    mid: Color(0xFFFFE066),
    glowInner: Color(0x52FFE066),
    glowOuter: Color(0x24FFB84D),
  ),
);

const _GardenLevelVisualSpec _middaySpec = _GardenLevelVisualSpec(
  code: 'A2',
  label: 'Midday Grove',
  sky: _middaySky,
  hill: _middayHill,
  iconAsset: 'assets/garden/plants/midday-grove-icon.svg',
  ambientKind: _GardenAmbientKind.bee,
  fenceCount: 5,
  showWildflowers: true,
  hillTop: 170,
  hillLeftYOffset: 38,
  hillRightYOffset: 28,
  sun: _GardenSunSpec(
    left: 336,
    top: 72,
    size: 72,
    core: Color(0xFFFFFDF0),
    mid: Color(0xFFFFD666),
    glowInner: Color(0x66FFE066),
    glowOuter: Color(0x2EFFB84D),
  ),
);

String _levelCode(String level) => level.trim().toUpperCase();

_GardenLevelVisualSpec _visualSpecFor(String level) {
  switch (_levelCode(level)) {
    case 'A0':
      return _dawnSpec;
    case 'A1':
      return _morningSpec;
    case 'A2':
      return _middaySpec;
    default:
      return _middaySpec;
  }
}

bool _isKnownGardenLevel(String level) =>
    const {'A0', 'A1', 'A2'}.contains(_levelCode(level));

String _gardenDisplayName(GardenData data, _GardenLevelVisualSpec spec) {
  if (_isKnownGardenLevel(data.level)) return spec.label;
  final theme = data.theme.trim();
  if (theme.isNotEmpty) return theme;
  final label = data.levelLabel.trim();
  return label.isNotEmpty ? label : spec.label;
}

// First-time welcome copy (Figma "Shift to new garden and nudge to start
// talking") — shown under a spotlight when arriving from placement.
const String _kWelcomeTitle = 'Welcome to your garden!';
const String _kWelcomeBody =
    'Each time we talk, a new plant grows here. Ready?';
const String _kWelcomeText = '$_kWelcomeTitle\n$_kWelcomeBody';
const String _kGardenButtonPlantIcon = 'assets/homescreen/new/Plant.svg';

enum _FirstGardenPhase { waiting, speaking, exploreReady, settled }

class GardenScreen extends ConsumerStatefulWidget {
  final VoidCallback? onConversationEnded;

  /// True when arriving from the placement bloom: shows a spotlight + Zoe's
  /// "Welcome to your garden" nudge, then unlocks the normal garden.
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

  late _FirstGardenPhase _firstGardenPhase = widget.firstTime
      ? _FirstGardenPhase.waiting
      : _FirstGardenPhase.settled;
  ZoeMascotMode _welcomeZoeMode = ZoeMascotMode.listening;
  bool _firstGardenStarted = false;
  bool _soundOn = true;
  final List<Timer> _timers = [];
  Set<String> _recentlyGrownSkillIds = {};

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioProvider);
    _soundOn = _audio.musicEnabled && _audio.sfxEnabled;
    // Start on every mount so the loop is audible each time the garden opens
    // (not just the first time).
    _startMusic();
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
    if (widget.firstTime && !_firstGardenStarted) {
      _firstGardenStarted = true;
      final reducedMotion = MediaQuery.of(context).disableAnimations;
      _after(reducedMotion ? 0 : 1000, _beginFirstGardenWelcome);
    }
  }

  void _after(int ms, VoidCallback fn) {
    final timer = Timer(Duration(milliseconds: ms), () {
      if (mounted) fn();
    });
    _timers.add(timer);
  }

  void _beginFirstGardenWelcome() {
    if (_firstGardenPhase != _FirstGardenPhase.waiting) return;
    setState(() {
      _firstGardenPhase = _FirstGardenPhase.speaking;
      _welcomeZoeMode = ZoeMascotMode.speaking;
    });
    unawaited(_speakWelcomeAndUnlockExplore());
  }

  Future<void> _speakWelcomeAndUnlockExplore() async {
    Timer? fallback;
    fallback = Timer(const Duration(milliseconds: 5200), () {
      if (mounted) _markFirstGardenExploreReady();
    });
    _timers.add(fallback);
    await _speakWelcomeLine();
    fallback.cancel();
    if (mounted) _markFirstGardenExploreReady();
  }

  Future<void> _speakWelcomeLine() async {
    final tts = ref.read(ttsProvider);
    if (tts.isSpeaking) return;
    try {
      await tts.stop();
      if (!mounted) return;
      setState(() => _welcomeZoeMode = ZoeMascotMode.speaking);
      await tts.speak(_kWelcomeText);
    } catch (_) {}
    if (mounted) setState(() => _welcomeZoeMode = ZoeMascotMode.listening);
  }

  void _markFirstGardenExploreReady() {
    if (_firstGardenPhase != _FirstGardenPhase.speaking) return;
    setState(() {
      _firstGardenPhase = _FirstGardenPhase.exploreReady;
      _welcomeZoeMode = ZoeMascotMode.listening;
    });
  }

  void _onExploreFirstGarden() {
    if (_firstGardenPhase != _FirstGardenPhase.exploreReady) return;
    setState(() => _firstGardenPhase = _FirstGardenPhase.settled);
  }

  void _returnHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
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
  Set<String> _registerAndDetectGrowth(GardenData data) {
    final next = <String, int>{};
    for (final step in data.steps) {
      for (final skill in step.skills) {
        next[skill.id] = skill.sightings;
      }
    }
    final grown = <String>{};
    if (_lastSightings.isNotEmpty) {
      for (final entry in next.entries) {
        if (entry.value > (_lastSightings[entry.key] ?? 0)) {
          grown.add(entry.key);
        }
      }
    }
    _lastSightings = next;
    return grown;
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
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
      final grownSkillIds = _registerAndDetectGrowth(data);
      if (grownSkillIds.isNotEmpty) {
        if (mounted) {
          setState(() => _recentlyGrownSkillIds = grownSkillIds);
        }
        ref.read(audioProvider).playSfx(Sounds.newSprout);
      } else if (_recentlyGrownSkillIds.isNotEmpty && mounted) {
        setState(() => _recentlyGrownSkillIds = {});
      }
    });
    final gardenAsync = ref.watch(gardenProvider);
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final introActive =
        widget.firstTime &&
        (_firstGardenPhase == _FirstGardenPhase.speaking ||
            _firstGardenPhase == _FirstGardenPhase.exploreReady);
    final showFirstExplore =
        widget.firstTime && _firstGardenPhase == _FirstGardenPhase.exploreReady;
    final showTalkBar =
        !widget.firstTime || _firstGardenPhase == _FirstGardenPhase.settled;
    final garden = Container(
      color: _middaySpec.hill.last,
      child: gardenAsync.when(
        data: (data) => _GardenView(
          data: data,
          soundOn: _soundOn,
          onToggleSound: _toggleSound,
          showTalkBar: showTalkBar,
          grownSkillIds: _recentlyGrownSkillIds,
          onBack: widget.firstTime ? _returnHome : null,
          onTalk: _returnHome,
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
    // real level garden, then the child explicitly unlocks the settled garden.
    final child = Stack(
      fit: StackFit.expand,
      children: [
        garden,
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: introActive ? 1 : 0,
            duration: Duration(milliseconds: reducedMotion ? 0 : 600),
            child: const SpotlightOverlay(center: Alignment(0, 0.26)),
          ),
        ),
        IgnorePointer(
          ignoring: !introActive,
          child: AnimatedOpacity(
            opacity: introActive ? 1 : 0,
            duration: Duration(milliseconds: reducedMotion ? 0 : 600),
            child: _WelcomeCallout(
              zoeMode: _welcomeZoeMode,
              reducedMotion: reducedMotion,
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: Duration(milliseconds: reducedMotion ? 0 : 450),
          child: showFirstExplore
              ? Align(
                  key: const ValueKey('garden-first-explore-layer'),
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 22,
                    ),
                    child: _GardenIntroButton(
                      key: const ValueKey('garden-first-explore'),
                      label: 'Explore Garden',
                      width: math.min(
                        202.0,
                        MediaQuery.of(context).size.width - 96,
                      ),
                      onTap: _onExploreFirstGarden,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnHome();
      },
      child: child,
    );
  }
}

class _WelcomeCallout extends StatelessWidget {
  final ZoeMascotMode zoeMode;
  final bool reducedMotion;
  const _WelcomeCallout({required this.zoeMode, required this.reducedMotion});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final width = constraints.maxWidth;
        final scale = (width / _designWidth).clamp(0.84, 1.08).toDouble();
        final bubbleLeft = 24.0;
        final bubbleWidth = width - 48;
        final bubbleTop = media.padding.top + 126 * scale;
        final mascotLeft = math.max(16.0, bubbleLeft - 6 * scale);
        final mascotTop = math.max(
          media.padding.top + 16 + 104 * 0.62,
          bubbleTop - 58 * scale,
        );

        // Bubble first, then the mascot, so Zoe renders IN FRONT of the bubble
        // (consistent with the placement spotlight callout).
        return Stack(
          children: [
            Positioned(
              left: bubbleLeft,
              top: bubbleTop,
              width: bubbleWidth,
              child: const _WelcomeBubble(),
            ),
            Positioned(
              left: mascotLeft,
              top: mascotTop,
              child: ZoeMascot(
                mode: zoeMode,
                size: 72 * scale,
                reducedMotion: reducedMotion,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WelcomeBubble extends StatelessWidget {
  const _WelcomeBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garden-first-welcome-bubble'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        side: const BorderSide(color: EllaColors.info, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                _kGardenButtonPlantIcon,
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  EllaColors.greenDeep,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _kWelcomeTitle,
                    maxLines: 1,
                    style: EllaTextStyles.bodySemiboldLarge.copyWith(
                      color: EllaColors.greenDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _kWelcomeBody,
            style: EllaTextStyles.bodySemiboldLarge.copyWith(
              color: EllaColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _GardenIntroButton extends StatelessWidget {
  final String label;
  final double width;
  final VoidCallback onTap;
  const _GardenIntroButton({
    super.key,
    required this.label,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Container(
        width: width,
        height: 56,
        decoration: ellaSmoothDecoration(
          color: EllaColors.berryMain,
          borderRadius: BorderRadius.circular(100),
          side: const BorderSide(color: EllaColors.berryDeep, width: 3),
          shadows: const [
            BoxShadow(
              color: EllaColors.berryDeep,
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              _kGardenButtonPlantIcon,
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                EllaColors.onPrimary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EllaTextStyles.buttonSmall.copyWith(
                  color: EllaColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
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

class _GardenView extends ConsumerStatefulWidget {
  final GardenData data;
  final bool soundOn;
  final VoidCallback onToggleSound;
  final bool showTalkBar;
  final Set<String> grownSkillIds;
  final VoidCallback? onBack;
  final VoidCallback onTalk;
  const _GardenView({
    required this.data,
    required this.soundOn,
    required this.onToggleSound,
    required this.showTalkBar,
    required this.grownSkillIds,
    required this.onBack,
    required this.onTalk,
  });

  @override
  ConsumerState<_GardenView> createState() => _GardenViewState();
}

class _GardenViewState extends ConsumerState<_GardenView> {
  late final ScrollController _scrollController;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final next = _scrollController.offset;
    if ((next - _scrollOffset).abs() < 0.5) return;
    setState(() => _scrollOffset = next);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final spec = _visualSpecFor(data.level);
    final media = MediaQuery.of(context);
    final childName =
        ref.watch(onboardingProvider).valueOrNull?.name?.trim() ?? '';
    final titleName = childName.isEmpty ? 'Narendra' : childName;
    final levelName = _gardenDisplayName(data, spec);

    return Stack(
      children: [
        Positioned.fill(
          child: _GardenBackdrop(
            key: ValueKey('garden-backdrop-${spec.code}'),
            spec: spec,
          ),
        ),
        Positioned.fill(
          child: SingleChildScrollView(
            controller: _scrollController,
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
                          spec: spec,
                          grownSkillIds: widget.grownSkillIds,
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
            spec: spec,
            levelName: levelName,
            gardenTitle: "$titleName's Garden",
            scrollProgress: (_scrollOffset / 88).clamp(0.0, 1.0),
            soundOn: widget.soundOn,
            onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
            onToggleSound: widget.onToggleSound,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 450,
            ),
            child: widget.showTalkBar
                ? _LetsTalkBar(
                    key: const ValueKey('garden-talk-bar-layer'),
                    // The button returns to Home, where the child picks a topic
                    // and starts a session (the garden no longer starts one
                    // directly).
                    onTalk: widget.onTalk,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// ── Level sky, header and scrolling units ────────────────────────────────────

class _GardenBackdrop extends StatelessWidget {
  final _GardenLevelVisualSpec spec;
  const _GardenBackdrop({super.key, required this.spec});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / _designWidth).clamp(0.86, 1.14);
        final sun = spec.sun;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _GardenBackdropPainter(spec: spec)),
            if (sun != null)
              Positioned(
                left: sun.left * scale,
                top: sun.top * scale,
                child: _GardenSun(spec: sun, size: sun.size * scale),
              ),
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
      },
    );
  }
}

class _GardenBackdropPainter extends CustomPainter {
  final _GardenLevelVisualSpec spec;
  const _GardenBackdropPainter({required this.spec});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final skyH = math.min(h, spec.hillTop + 104);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, skyH),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: spec.sky,
          stops: _gardenStops,
        ).createShader(Rect.fromLTWH(0, 0, w, skyH)),
    );

    final hill = Path()
      ..moveTo(0, spec.hillTop + spec.hillLeftYOffset)
      ..cubicTo(
        w * 0.20,
        spec.hillTop + 7,
        w * 0.37,
        spec.hillTop - 5,
        w * 0.53,
        spec.hillTop,
      )
      ..cubicTo(
        w * 0.70,
        spec.hillTop + 1,
        w * 0.86,
        spec.hillTop + 15,
        w,
        spec.hillTop + spec.hillRightYOffset,
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      hill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: spec.hill,
          stops: _gardenStops,
        ).createShader(Rect.fromLTWH(0, spec.hillTop, w, h - spec.hillTop)),
    );
  }

  @override
  bool shouldRepaint(_GardenBackdropPainter oldDelegate) =>
      oldDelegate.spec != spec;
}

class _GardenSun extends StatelessWidget {
  final _GardenSunSpec spec;
  final double size;
  const _GardenSun({required this.spec, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [spec.core, spec.mid, spec.glowInner, spec.glowOuter],
          stops: const [0, 0.42, 0.72, 1],
        ),
      ),
    );
  }
}

class _PinnedGardenHeader extends StatelessWidget {
  final _GardenLevelVisualSpec spec;
  final String levelName;
  final String gardenTitle;
  final double scrollProgress;
  final bool soundOn;
  final VoidCallback onBack;
  final VoidCallback onToggleSound;

  const _PinnedGardenHeader({
    required this.spec,
    required this.levelName,
    required this.gardenTitle,
    required this.scrollProgress,
    required this.soundOn,
    required this.onBack,
    required this.onToggleSound,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final pillW = _levelPillWidthFor(levelName);
    final rowTop = top + _headerTopGap;
    final pillLeft = _headerSidePadding + _headerButtonSize + _headerButtonGap;
    final titleTargetY = rowTop + _levelPillH + 16;
    final titleStartY = top + 84;
    final progress = scrollProgress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleW = math.min(constraints.maxWidth - 32, 386.0);
        final startCenter = constraints.maxWidth / 2;
        final targetCenter = pillLeft + pillW / 2;
        final titleCenter = lerpDouble(startCenter, targetCenter, progress)!;
        final titleTop = lerpDouble(titleStartY, titleTargetY, progress)!;
        final titleSize = lerpDouble(18, 16, progress)!;

        return SizedBox(
          height: top + _pinnedSkyHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: _headerSidePadding,
                right: 20,
                top: rowTop,
                child: Row(
                  children: [
                    _HeaderCircleButton(
                      onTap: onBack,
                      icon: Icons.arrow_back_rounded,
                      fill: Colors.transparent,
                      iconColor: EllaColors.greenDeep,
                      border: EllaColors.greenDeep,
                    ),
                    const SizedBox(width: _headerButtonGap),
                    _LevelSelectorPill(
                      levelName: levelName,
                      iconAsset: spec.iconAsset,
                      width: pillW,
                    ),
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
              ),
              Positioned(
                left: titleCenter - titleW / 2,
                top: titleTop,
                width: titleW,
                child: Text(
                  gardenTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EllaFonts.bricolage(
                    TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                      letterSpacing: 0,
                      color: EllaColors.ink,
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

double _levelPillWidthFor(String name) {
  if (name.length > 13) return 234;
  if (name.length > 11) return 205;
  return 190;
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
        width: _headerButtonSize,
        height: _headerButtonSize,
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
  final String iconAsset;
  final double width;
  const _LevelSelectorPill({
    required this.levelName,
    required this.iconAsset,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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
          SvgPicture.asset(iconAsset, width: 24, height: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
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
  final _GardenLevelVisualSpec spec;
  final Set<String> grownSkillIds;
  const _GardenUnitRow({
    required this.data,
    required this.step,
    required this.index,
    required this.spec,
    required this.grownSkillIds,
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
        final fenceX = plotOnLeft
            ? 47.0
            : 390.0 - _fenceRunSize(spec.fenceCount, !plotOnLeft).width;
        final fenceY = plotOnLeft
            ? 245.0
            : (spec.fenceCount >= 5
                  ? 255.0
                  : (spec.fenceCount >= 4 ? 239.0 : 235.0));
        final accentOffset = _groundAccentOffsetFor(
          spec,
          plotOnLeft: plotOnLeft,
          plotY: plotY,
        );
        final ambientOffset = _ambientOffsetFor(
          spec,
          index: index,
          plotOnLeft: plotOnLeft,
          plotY: plotY,
        );

        return SizedBox(
          key: ValueKey('garden-unit-${step.step}'),
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
                          child: _Plot(
                            data: data,
                            step: step,
                            grownSkillIds: grownSkillIds,
                          ),
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
                          child: _FenceRun(
                            leansRight: !plotOnLeft,
                            count: spec.fenceCount,
                          ),
                        ),
                        Positioned(
                          left: accentOffset.dx,
                          top: accentOffset.dy,
                          child: _GroundAccent(spec: spec),
                        ),
                        if (step.hasGrowth || index < 4)
                          Positioned(
                            left: ambientOffset.dx,
                            top: ambientOffset.dy,
                            child: _AmbientCreature(kind: spec.ambientKind),
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

Offset _groundAccentOffsetFor(
  _GardenLevelVisualSpec spec, {
  required bool plotOnLeft,
  required double plotY,
}) {
  if (!spec.showWildflowers) {
    return Offset(
      plotOnLeft ? 334.0 : 56.0,
      plotOnLeft ? plotY + 124.0 : 247.0,
    );
  }
  if (spec.code == 'A1') {
    return plotOnLeft ? const Offset(348, 211) : const Offset(59, 242);
  }
  return plotOnLeft ? const Offset(356, 171) : const Offset(46, 216);
}

Offset _ambientOffsetFor(
  _GardenLevelVisualSpec spec, {
  required int index,
  required bool plotOnLeft,
  required double plotY,
}) {
  switch (spec.ambientKind) {
    case _GardenAmbientKind.butterfly:
      return Offset(
        plotOnLeft ? (index == 0 ? 64.0 : 108.0) : 223.0,
        plotOnLeft ? plotY - 4.0 : plotY + 44.0,
      );
    case _GardenAmbientKind.bird:
      return plotOnLeft ? const Offset(156, 210) : const Offset(182, 202);
    case _GardenAmbientKind.bee:
      return plotOnLeft ? const Offset(90, 73) : const Offset(353, 82);
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
  final int count;
  const _FenceRun({required this.leansRight, required this.count});

  @override
  Widget build(BuildContext context) {
    final positions = _fenceOffsets(count, leansRight);
    final size = _fenceRunSize(count, leansRight);
    return SizedBox(
      width: size.width,
      height: size.height,
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

List<Offset> _fenceOffsets(int count, bool leansRight) {
  final normalized = count.clamp(3, 5).toInt();
  if (leansRight) {
    return switch (normalized) {
      5 => const [
        Offset(0, 30),
        Offset(48, 30),
        Offset(94, 30),
        Offset(142, 21),
        Offset(189, 0),
      ],
      4 => const [
        Offset(0, 30),
        Offset(48, 30),
        Offset(96, 21),
        Offset(143, 0),
      ],
      _ => const [Offset(0, 30), Offset(48, 21), Offset(95, 0)],
    };
  }
  return switch (normalized) {
    5 => const [
      Offset(0, 0),
      Offset(47, 12),
      Offset(99, 24),
      Offset(146, 24),
      Offset(194, 24),
    ],
    4 => const [Offset(0, 0), Offset(47, 12), Offset(99, 24), Offset(147, 24)],
    _ => const [Offset(0, 0), Offset(47, 12), Offset(99, 24)],
  };
}

Size _fenceRunSize(int count, bool leansRight) {
  final positions = _fenceOffsets(count, leansRight);
  final maxX = positions.map((o) => o.dx).reduce(math.max);
  final maxY = positions.map((o) => o.dy).reduce(math.max);
  return Size(maxX + 40, maxY + 24);
}

class _GroundAccent extends StatelessWidget {
  final _GardenLevelVisualSpec spec;
  const _GroundAccent({required this.spec});

  @override
  Widget build(BuildContext context) {
    if (!spec.showWildflowers) return const _GrassTuft();
    return SvgPicture.asset(
      'assets/garden/ambient/wildflowers.svg',
      width: 36,
      height: 31,
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
  final Set<String> grownSkillIds;
  const _Plot({
    required this.data,
    required this.step,
    required this.grownSkillIds,
  });

  @override
  Widget build(BuildContext context) {
    final skills = step.skills;
    final tileSpots = _tileSpotsFor(skills.length);

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
                animateGrowth: grownSkillIds.contains(skills[i].id),
                onTap: () => showSkillSheet(context, step, skills[i]),
              ),
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
        key: ValueKey('garden-skill-tile-${skill.id}'),
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
  final bool animateGrowth;
  final VoidCallback onTap;
  const _SkillPlant({
    required this.skill,
    required this.spot,
    required this.swayDelayMs,
    required this.animateGrowth,
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
          child: _Plant(
            skill: skill,
            swayDelayMs: swayDelayMs,
            animateGrowth: animateGrowth,
            onTap: onTap,
          ),
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

// Idle plant sway: rotation ±4° about the bottom-centre, 2400ms ping-pong.
const double _swayMaxRad = 4.0 * math.pi / 180;

class _Plant extends StatefulWidget {
  final GardenSkill skill;
  final int swayDelayMs;
  final bool animateGrowth;
  final VoidCallback onTap;
  const _Plant({
    required this.skill,
    required this.swayDelayMs,
    required this.animateGrowth,
    required this.onTap,
  });

  @override
  State<_Plant> createState() => _PlantState();
}

class _PlantState extends State<_Plant> with TickerProviderStateMixin {
  // Idle sway loop (1a) and one-shot pop-in (2a) from the grove handoff.
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
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
  Timer? _swayDelayTimer;

  void _start() {
    if (_started) return;
    _started = true;
    // Existing plants enter at rest. Only real post-refresh growth receives
    // the pop animation.
    if (widget.animateGrowth) {
      _pop.forward(from: 0);
    } else {
      _pop.value = 1;
    }
    if (widget.swayDelayMs <= 0) {
      _sway.repeat(reverse: true);
    } else {
      _swayDelayTimer = Timer(Duration(milliseconds: widget.swayDelayMs), () {
        if (mounted) _sway.repeat(reverse: true);
      });
    }
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
  void didUpdateWidget(covariant _Plant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (MediaQuery.of(context).disableAnimations) {
      _pop.value = 1;
      return;
    }
    final grew =
        widget.animateGrowth &&
        (!oldWidget.animateGrowth ||
            widget.skill.sightings > oldWidget.skill.sightings);
    if (grew) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _swayDelayTimer?.cancel();
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
          key: ValueKey('garden-plant-scale-${widget.skill.id}'),
          scale: _popScale.value,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
      child: art,
    );
  }
}

class _AmbientCreature extends StatelessWidget {
  final _GardenAmbientKind kind;
  const _AmbientCreature({required this.kind});

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      _GardenAmbientKind.butterfly => const _Butterfly(),
      _GardenAmbientKind.bird => const _Bird(),
      _GardenAmbientKind.bee => const _Bee(),
    };
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
        width: 32,
        height: 32,
      ),
    );
  }
}

class _Bird extends StatefulWidget {
  const _Bird();

  @override
  State<_Bird> createState() => _BirdState();
}

class _BirdState extends State<_Bird> with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) return;
    if (!_hop.isAnimating) _hop.repeat();
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hop,
      builder: (_, child) {
        final forward = _hop.value < 0.5;
        final t = forward ? _hop.value * 2 : (_hop.value - 0.5) * 2;
        final eased = Curves.easeInOut.transform(t);
        final x = forward
            ? lerpDouble(0, 22, eased)!
            : lerpDouble(22, 0, eased)!;
        final y = -math.sin(t * math.pi) * 4;
        return Transform.translate(
          offset: Offset(x, y),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(forward ? 1 : -1, 1, 1),
            child: child,
          ),
        );
      },
      child: SvgPicture.asset(
        'assets/garden/ambient/bird.svg',
        width: 32,
        height: 27,
      ),
    );
  }
}

class _Bee extends StatefulWidget {
  const _Bee();

  @override
  State<_Bee> createState() => _BeeState();
}

class _BeeState extends State<_Bee> with SingleTickerProviderStateMixin {
  late final AnimationController _buzz = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3800),
  );

  late final Animation<double> _x = _seq(const [0, 8, 4, -6, 0]);
  late final Animation<double> _y = _seq(const [0, -8, -2, -10, 0]);

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
    ]).animate(_buzz);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) return;
    if (!_buzz.isAnimating) _buzz.repeat();
  }

  @override
  void dispose() {
    _buzz.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _buzz,
      builder: (_, child) =>
          Transform.translate(offset: Offset(_x.value, _y.value), child: child),
      child: SvgPicture.asset(
        'assets/garden/ambient/bee.svg',
        width: 24,
        height: 24,
      ),
    );
  }
}

// ── Bottom "Let's Talk" bar ────────────────────────────────────────────────────

class _LetsTalkBar extends StatelessWidget {
  final VoidCallback onTalk;
  const _LetsTalkBar({super.key, required this.onTalk});

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
                      decoration: ellaSmoothDecoration(
                        color: EllaColors.berryMain,
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(
                          color: EllaColors.berryDeep,
                          width: 3,
                        ),
                        shadows: const [
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
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "Let's Talk",
                                maxLines: 1,
                                style: EllaFonts.body(
                                  const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.6,
                                    color: EllaColors.onPrimary,
                                  ),
                                ),
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
