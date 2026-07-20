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

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/app_toast.dart';
import '../../core/ella_smooth_shape.dart';
import '../../route_observer.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/garden.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/garden_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/audio_service.dart';
import '../../services/sounds.dart';
import '../../services/stt_tts_service.dart';
import 'widgets/garden_dialogs.dart';
import 'widgets/spotlight_callout_bubble.dart';
import 'widgets/spotlight_overlay.dart';
import 'widgets/zoe_mascot.dart';
import 'widgets/network_error_view.dart';
import 'widgets/mascot_loading_screen.dart';

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
const List<Color> _goldenSky = [
  Color(0xFFFFF3D4),
  Color(0xFFFFD9A0),
  Color(0xFFF9E8B8),
];
const List<Color> _goldenHill = [
  Color(0xFFE8DE9C),
  Color(0xFFB8C468),
  Color(0xFF7A8A3A),
];
const List<Color> _twilightSky = [
  Color(0xFF9B8AC4),
  Color(0xFFD9A8C0),
  Color(0xFFFFCFAE),
];
const List<Color> _twilightHill = [
  Color(0xFFA8C488),
  Color(0xFF5C8A5C),
  Color(0xFF2F4A38),
];
const List<Color> _starlightSky = [
  Color(0xFF1A1F3D),
  Color(0xFF3D3468),
  Color(0xFF6B5A94),
];
const List<Color> _starlightHill = [
  Color(0xFF4A6250),
  Color(0xFF26362E),
  Color(0xFF141F1A),
];
const List<double> _gardenStops = [0, 0.55, 1];

const double _designWidth = 430;
const double _pinnedSkyHeight = 176;
const double _scrollStartY = 236;
const double _ctaFadeHeight = 84;
const double _unitRowH = 345;
const double _plotW = 287.32;
const double _plotH = 143;
const double _tileW = 105;
const double _tileH = 80;
// Slot the flower art sits in; enlarged with the plant heights below.
const double _plantSlotW = 87.4;
const double _plantBaseFactor = 0.50;
// Plant SVGs share a 90×100 viewBox with the stem base at y≈92 (translate(45,92)),
// so the visible base sits at this fraction down the plantHeight box. Anchoring by
// the base (not the box bottom) roots every growth stage at the same tile point.
const double _plantBaseYFrac = 0.92;
const double _ellipseW = 287.32;
const double _ellipseH = 130;
const double _fenceSegmentW = 57.6;
const double _fenceSegmentH = 34.8;
const double _cloudW = 60;
const double _headerSidePadding = 24;
const double _headerTopGap = 16;
const double _headerButtonSize = 30;
const double _levelPillH = 48;

enum _GardenAmbientKind { butterfly, goldenButterfly, bird, bee, firefly }

enum _GardenSideProp { grassTuft, wildflowers, mushrooms, lantern }

enum _GardenClouds { none, left, both }

class _GardenStarSpec {
  final double left;
  final double top;
  final double size;

  const _GardenStarSpec(this.left, this.top, this.size);
}

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
  final _GardenSideProp sideProp;
  final _GardenClouds clouds;
  final int fenceCount;
  final double hillTop;
  final double hillLeftYOffset;
  final double hillRightYOffset;
  final Color titleColor;
  final Color? bushTint;
  final List<_GardenStarSpec> stars;
  final _GardenSunSpec? sun;

  const _GardenLevelVisualSpec({
    required this.code,
    required this.label,
    required this.sky,
    required this.hill,
    required this.iconAsset,
    required this.ambientKind,
    required this.sideProp,
    required this.clouds,
    required this.fenceCount,
    required this.hillTop,
    required this.hillLeftYOffset,
    required this.hillRightYOffset,
    this.titleColor = EllaColors.ink,
    this.bushTint,
    this.stars = const [],
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
  sideProp: _GardenSideProp.grassTuft,
  clouds: _GardenClouds.both,
  fenceCount: 3,
  hillTop: 200,
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
  sideProp: _GardenSideProp.wildflowers,
  clouds: _GardenClouds.both,
  fenceCount: 4,
  hillTop: 194,
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
  sideProp: _GardenSideProp.wildflowers,
  clouds: _GardenClouds.both,
  fenceCount: 5,
  hillTop: 194,
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

const _GardenLevelVisualSpec _goldenSpec = _GardenLevelVisualSpec(
  code: 'B1',
  label: 'Golden Orchard',
  sky: _goldenSky,
  hill: _goldenHill,
  iconAsset: 'assets/garden/plants/golden-orchard-icon.svg',
  ambientKind: _GardenAmbientKind.goldenButterfly,
  sideProp: _GardenSideProp.mushrooms,
  clouds: _GardenClouds.left,
  fenceCount: 6,
  hillTop: 194,
  hillLeftYOffset: 38,
  hillRightYOffset: 28,
  bushTint: Color(0xFFE2D37A),
  sun: _GardenSunSpec(
    left: 336,
    top: 104,
    size: 72,
    core: Color(0xFFFFEAC2),
    mid: Color(0xFFFFC15E),
    glowInner: Color(0x6BFFC15E),
    glowOuter: Color(0x29FFAA00),
  ),
);

const _GardenLevelVisualSpec _twilightSpec = _GardenLevelVisualSpec(
  code: 'B2',
  label: 'Twilight Valley',
  sky: _twilightSky,
  hill: _twilightHill,
  iconAsset: 'assets/garden/plants/twilight-valley-icon.svg',
  ambientKind: _GardenAmbientKind.firefly,
  sideProp: _GardenSideProp.mushrooms,
  clouds: _GardenClouds.none,
  fenceCount: 8,
  hillTop: 194,
  hillLeftYOffset: 38,
  hillRightYOffset: 28,
  titleColor: EllaColors.onPrimary,
  bushTint: Color(0xFF86A16E),
  sun: _GardenSunSpec(
    left: 27,
    top: 89,
    size: 48,
    core: Color(0xFFF8F4FF),
    mid: Color(0xFFE4D8F5),
    glowInner: Color(0x66D8CCF0),
    glowOuter: Color(0x299B8AC4),
  ),
);

const _GardenLevelVisualSpec _starlightSpec = _GardenLevelVisualSpec(
  code: 'C1',
  label: 'Starlight Summit',
  sky: _starlightSky,
  hill: _starlightHill,
  iconAsset: 'assets/garden/plants/starlight-summit-icon.svg',
  ambientKind: _GardenAmbientKind.firefly,
  sideProp: _GardenSideProp.lantern,
  clouds: _GardenClouds.none,
  fenceCount: 10,
  hillTop: 194,
  hillLeftYOffset: 38,
  hillRightYOffset: 28,
  titleColor: EllaColors.onPrimary,
  bushTint: Color(0xFF506858),
  stars: [
    _GardenStarSpec(101, 9, 4),
    _GardenStarSpec(323, 65, 2),
    _GardenStarSpec(405, 63, 2),
    _GardenStarSpec(355, 91, 4),
    _GardenStarSpec(59, 118, 2),
    _GardenStarSpec(273, 136, 2),
    _GardenStarSpec(36, 147, 4),
    _GardenStarSpec(140, 144, 4),
    _GardenStarSpec(381, 166, 4),
  ],
  sun: _GardenSunSpec(
    left: 69,
    top: 46,
    size: 72,
    core: Color(0xFFF7F5FF),
    mid: Color(0xFFDCD4F0),
    glowInner: Color(0x73F7F5FF),
    glowOuter: Color(0x26B4C8FF),
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
    case 'B1':
      return _goldenSpec;
    case 'B2':
      return _twilightSpec;
    case 'C1':
      return _starlightSpec;
    default:
      return _middaySpec;
  }
}

bool _isKnownGardenLevel(String level) =>
    const {'A0', 'A1', 'A2', 'B1', 'B2', 'C1'}.contains(_levelCode(level));

String _gardenDisplayName(GardenData data, _GardenLevelVisualSpec spec) {
  if (_isKnownGardenLevel(data.level)) return spec.label;
  final theme = data.theme.trim();
  if (theme.isNotEmpty) return theme;
  final label = data.levelLabel.trim();
  return label.isNotEmpty ? label : spec.label;
}

// First-time welcome copy (Figma "Shift to new garden and nudge to start
// talking") — shown under a spotlight when arriving from placement.
const String _kWelcomeTitle = "Here's your first plant";
const String _kWelcomeBody = 'Every conversation helps your garden grow.';
const String _kWelcomeText = '$_kWelcomeTitle. $_kWelcomeBody';
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

class _GardenScreenState extends ConsumerState<GardenScreen>
    with RouteAware, WidgetsBindingObserver {
  // Last-seen garden payload while this screen is mounted. Used for the rare
  // case where a conversation ends while the garden is already visible. Normal
  // post-chat reveals are queued by ChatNotifier from an exact before/after
  // backend diff.
  GardenData? _lastGardenData;

  // Captured in initState so dispose() never reads `ref` (unreliable while the
  // element is deactivating) — otherwise the stop-on-leave can silently fail.
  late final AudioInterface _audio;
  late final TtsInterface _tts;

  late _FirstGardenPhase _firstGardenPhase = widget.firstTime
      ? _FirstGardenPhase.waiting
      : _FirstGardenPhase.settled;
  ZoeMascotMode _welcomeZoeMode = ZoeMascotMode.listening;
  bool _firstGardenStarted = false;
  bool _soundOn = true;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('Garden');
    _audio = ref.read(audioProvider);
    _tts = ref.read(ttsProvider);
    _soundOn = _audio.musicEnabled && _audio.sfxEnabled;
    // Start on every mount so the loop is audible each time the garden opens
    // (not just the first time).
    _startMusic();
    WidgetsBinding.instance.addObserver(this);
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
    unawaited(_audio.playSfx(Sounds.newGarden));
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
    try {
      _tts.stop();
    } catch (_) {}
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

  bool _gardenReflectsGrowthResult(
    GardenData data,
    PostConversationGardenReveal result,
    List<GardenGrowthRevealItem> growthItems,
  ) {
    final skills = <String, GardenSkill>{
      for (final step in data.steps)
        for (final skill in step.skills) skill.id: skill,
    };
    for (final item in growthItems) {
      final skill = skills[item.skillId];
      if (skill == null) return false;
      final expectedSightings = result.afterSightings[item.skillId];
      if (expectedSightings != null && skill.sightings < expectedSightings) {
        return false;
      }
      final expectedStatus = result.afterOwned.contains(item.skillId)
          ? SkillStatus.owned
          : result.afterEmerging.contains(item.skillId)
          ? SkillStatus.emerging
          : SkillStatus.locked;
      if (skill.status != expectedStatus) return false;
    }
    return true;
  }

  void _registerGardenForReveal(GardenData data) {
    final postConversation = ref.read(postConversationGardenRevealProvider);
    final revealQueue = ref.read(gardenGrowthRevealProvider);
    if (postConversation != null) {
      if (!postConversation.isResolved) return;
      if (revealQueue.isEmpty) {
        final growthItems = buildPostConversationGrowthRevealItems(
          after: data,
          result: postConversation,
        );
        if (growthItems.isNotEmpty) {
          // Growth waits until the garden payload itself contains the new
          // stage. Watering-only acknowledgements can use the cached garden.
          if (!_gardenReflectsGrowthResult(
            data,
            postConversation,
            growthItems,
          )) {
            return;
          }
          ref.read(gardenGrowthRevealProvider.notifier).setQueue(growthItems);
        } else {
          final watering = buildGardenWateringRevealItem(
            after: data,
            aimedAt: postConversation.targetSkillIds,
            fallbackSkillIds: postConversation.targetSkillIds,
            turnCount: postConversation.turnCount,
            sessionScores: postConversation.sessionScores,
          );
          if (watering != null) {
            ref.read(gardenGrowthRevealProvider.notifier).setQueue([watering]);
          }
        }
      }
      ref
          .read(postConversationGardenRevealProvider.notifier)
          .consume(postConversation.chatNumber);
      return;
    }

    final previous = _lastGardenData;
    _lastGardenData = data;
    if (revealQueue.isNotEmpty) return;

    final items = buildGardenGrowthRevealItems(before: previous, after: data);
    if (items.isNotEmpty) {
      ref.read(gardenGrowthRevealProvider.notifier).setQueue(items);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _timers) {
      timer.cancel();
    }
    try {
      _tts.stop();
    } catch (_) {}
    appRouteObserver.unsubscribe(this);
    _stopMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopMusic();
    } else if (state == AppLifecycleState.resumed && mounted) {
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
      if (isCurrent && _soundOn) {
        _startMusic();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // When refreshed garden data shows a skill has grown while this screen is
    // mounted, queue the same reveal flow used after conversations. Baseline is
    // set silently on the first payload.
    ref.listen<AsyncValue<GardenData>>(gardenProvider, (prev, next) {
      // A backend failure loading the garden shows the standard toast (once, on
      // the transition into error) instead of a separate error screen.
      if (next.hasError && !(prev?.hasError ?? false) && mounted) {
        debugPrint('[Garden] load error: ${next.error}');
        showEllaErrorToast(context);
      }
      if (next is! AsyncData<GardenData>) return;
      final data = next.value;
      _registerGardenForReveal(data);
    });
    // Treat losing connectivity like pausing the app: stop the ambient garden
    // loop so the offline state feels paused. Resume on reconnect only if this
    // is still the visible garden and sound is on. Tap SFX are unaffected.
    ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      final online = next.valueOrNull ?? true;
      if (!online) {
        _stopMusic();
      } else if (mounted && _soundOn) {
        final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
        if (isCurrent) _startMusic();
      }
    });
    final gardenAsync = ref.watch(gardenProvider);
    final postConversation = ref.watch(postConversationGardenRevealProvider);
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
        data: (data) {
          if (!gardenAsync.isRefreshing ||
              (postConversation?.isResolved ?? false)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _registerGardenForReveal(data);
            });
          }
          return _GardenView(
            data: data,
            soundOn: _soundOn,
            onToggleSound: _toggleSound,
            showTalkBar: showTalkBar,
            onBack: widget.firstTime ? _returnHome : null,
            onTalk: _returnHome,
          );
        },
        loading: () =>
            const MascotLoadingScreen(message: 'Preparing your garden...'),
        error: (e, _) =>
            NetworkErrorView(onRetry: () => ref.invalidate(gardenProvider)),
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
            // Tight radius + a slightly lower centre so the clear spotlight hugs
            // the first plot's plant while the surrounding garden is blurred and
            // darkened.
            child: const SpotlightOverlay(
              center: Alignment(0, 0.28),
              radius: 0.72,
            ),
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
                      label: 'See My Garden',
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
        // Same wide callout as the placement sprout reveal: a full-width card
        // (24px side margins) tucked just under the header controls, with Zoe
        // perched at its top-left corner sitting ON the card (its base overlaps
        // the top edge by ~14px) rather than floating above it.
        final bubbleWidth = width - 48;
        final bubbleLeft = 24.0;
        final bubbleTop = media.padding.top + 84 * scale;
        final mascotLeft = math.max(16.0, bubbleLeft - 6 * scale);
        final mascotTop = math.max(media.padding.top, bubbleTop - 58 * scale);

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
    // Same bubble as the placement reveal (Figma 598:17012) — only the copy
    // differs.
    return const SpotlightCalloutBubble(
      key: ValueKey('garden-first-welcome-bubble'),
      title: _kWelcomeTitle,
      body: _kWelcomeBody,
    );
  }
}

const String _kCompletedPreviousGardenMessage =
    'Look! Your earlier conversations have already grown this garden';

class _CompletedPreviousGardenIntroLayer extends StatelessWidget {
  final String levelLabel;
  final VoidCallback onExplore;

  const _CompletedPreviousGardenIntroLayer({
    required this.levelLabel,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reducedMotion = media.disableAnimations;
    return GestureDetector(
      key: const ValueKey('garden-completed-previous-intro'),
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black.withValues(alpha: 0.58)),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final scale = (width / _designWidth).clamp(0.84, 1.08).toDouble();
              final bubbleWidth = math.min(342 * scale, width - 40);
              final bubbleLeft = math.max(20.0, (width - bubbleWidth) / 2);
              final bubbleTop = media.padding.top + 182 * scale;
              final mascotSize = 72 * scale;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: math.max(16.0, bubbleLeft - 4 * scale),
                    top: math.max(
                      media.padding.top + 92,
                      bubbleTop - 58 * scale,
                    ),
                    child: ZoeMascot(
                      key: const ValueKey('garden-completed-previous-zoe'),
                      mode: ZoeMascotMode.listening,
                      size: mascotSize,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                  Positioned(
                    left: bubbleLeft,
                    top: bubbleTop,
                    width: bubbleWidth,
                    child: _CompletedPreviousGardenBubble(
                      levelLabel: levelLabel,
                    ),
                  ),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: media.padding.bottom + 22),
              child: _GardenIntroButton(
                key: const ValueKey('garden-completed-previous-explore'),
                label: 'See My Garden',
                width: math.min(202.0, media.size.width - 96),
                onTap: onExplore,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedPreviousGardenBubble extends StatelessWidget {
  final String levelLabel;

  const _CompletedPreviousGardenBubble({required this.levelLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garden-completed-previous-bubble'),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        side: const BorderSide(color: EllaColors.info, width: 3),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            offset: const Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            levelLabel,
            style: EllaTextStyles.bodySemibold.copyWith(
              color: EllaColors.infoDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            key: const ValueKey('garden-completed-previous-message'),
            _kCompletedPreviousGardenMessage,
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
  final VoidCallback? onBack;
  final VoidCallback onTalk;
  const _GardenView({
    required this.data,
    required this.soundOn,
    required this.onToggleSound,
    required this.showTalkBar,
    required this.onBack,
    required this.onTalk,
  });

  @override
  ConsumerState<_GardenView> createState() => _GardenViewState();
}

class _GardenViewState extends ConsumerState<_GardenView> {
  late final ScrollController _scrollController;
  final Map<String, GlobalKey> _skillAnchorKeys = {};
  final Map<int, GlobalKey> _plotAnchorKeys = {};
  final Map<String, GlobalKey> _skillPlotAnchorKeys = {};
  final List<Timer> _revealTimers = [];
  double _scrollOffset = 0;
  String? _activeRevealKey;
  GardenGrowthRevealItem? _activeRevealItem;
  Offset? _spotlightCenter;
  double _spotlightRadius = 0.62;
  double _wateringSpread = 24;
  bool _spotlightVisible = false;
  bool _wateringVisible = false;
  bool _wateringFromLeft = false;
  bool _pendingScoringWatering = false;
  bool _scoringWaitCardVisible = false;
  bool _cyclePourPeakReached = false;
  bool _pendingResultApplied = false;
  int _wateringCycle = 0;
  GardenGrowthRevealItem? _pendingResultItem;
  bool _cardVisible = false;
  bool _revealCtaReady = false;
  bool _revealAdvancing = false;
  ZoeMascotMode _revealZoeMode = ZoeMascotMode.listening;
  String? _poppingSkillId;
  int _revealToken = 0;

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

  void _showGardenSwitcherSheet({
    required String currentLevel,
    required String ownerFirstName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // Fill the screen so the sheet content can be centered vertically.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height,
      ),
      builder: (_) => _GardenSwitcherSheet(
        currentLevel: currentLevel,
        ownerFirstName: ownerFirstName,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _GardenView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data == widget.data) return;
    if (ref.read(gardenGrowthRevealProvider).isNotEmpty) return;
    final items = buildGardenGrowthRevealItems(
      before: oldWidget.data,
      after: widget.data,
    );
    if (items.isNotEmpty) {
      ref.read(gardenGrowthRevealProvider.notifier).setQueue(items);
    }
  }

  GlobalKey _skillAnchorKeyFor(String skillId) => _skillAnchorKeys.putIfAbsent(
    skillId,
    () => GlobalKey(debugLabel: 'garden-skill-anchor-$skillId'),
  );

  GlobalKey _plotAnchorKeyFor(GardenStep step) {
    final key = _plotAnchorKeys.putIfAbsent(
      step.step,
      () => GlobalKey(debugLabel: 'garden-plot-anchor-${step.step}'),
    );
    for (final skill in step.skills) {
      _skillPlotAnchorKeys[skill.id] = key;
    }
    return key;
  }

  void _cancelRevealTimers() {
    for (final timer in _revealTimers) {
      timer.cancel();
    }
    _revealTimers.clear();
  }

  void _afterReveal(int ms, VoidCallback fn) {
    final timer = Timer(Duration(milliseconds: ms), () {
      if (mounted) fn();
    });
    _revealTimers.add(timer);
  }

  void _syncRevealState(
    List<GardenGrowthRevealItem> queue,
    PostConversationGardenReveal? postConversation,
  ) {
    if (!mounted) return;
    if (_pendingScoringWatering) {
      if (queue.isNotEmpty && _pendingResultItem == null) {
        _bufferPendingResult(queue.first);
      }
      return;
    }
    if (queue.isEmpty) {
      if (_activeRevealKey != null) _resetRevealLayer();
      if (postConversation != null &&
          !postConversation.isResolved &&
          postConversation.turnCount >= 3) {
        final pendingItem = buildGardenWateringRevealItem(
          after: widget.data,
          aimedAt: postConversation.targetSkillIds,
          fallbackSkillIds: postConversation.targetSkillIds,
          turnCount: postConversation.turnCount,
        );
        if (pendingItem != null) _startPendingWatering(pendingItem);
      }
      return;
    }
    final item = queue.first;
    if (_activeRevealKey == item.revealKey) return;
    _startReveal(item);
  }

  void _startPendingWatering(GardenGrowthRevealItem item) {
    _cancelRevealTimers();
    final token = ++_revealToken;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    setState(() {
      _activeRevealKey = '${item.revealKey}:pending';
      _activeRevealItem = item;
      _pendingScoringWatering = true;
      _pendingResultItem = null;
      _pendingResultApplied = false;
      _wateringCycle = 0;
      _wateringFromLeft = false;
      _cyclePourPeakReached = false;
      _scoringWaitCardVisible = false;
      _spotlightCenter = null;
      _spotlightRadius = 0.9;
      _wateringSpread = 24;
      _spotlightVisible = false;
      _wateringVisible = false;
      _cardVisible = false;
      _revealCtaReady = false;
      _revealAdvancing = false;
      _revealZoeMode = ZoeMascotMode.listening;
      _poppingSkillId = null;
    });
    _afterReveal(
      reducedMotion ? 0 : 300,
      () => unawaited(_focusRevealPlant(item, token, pending: true)),
    );
  }

  bool _samePlot(GardenGrowthRevealItem first, GardenGrowthRevealItem second) =>
      first.step.step == second.step.step;

  void _bufferPendingResult(GardenGrowthRevealItem item) {
    if (!_pendingScoringWatering || _pendingResultItem != null) return;
    setState(() {
      _pendingResultItem = item;
      _scoringWaitCardVisible = false;
    });
    final pendingItem = _activeRevealItem;
    if (pendingItem != null &&
        _samePlot(pendingItem, item) &&
        _cyclePourPeakReached) {
      _applyPendingResultDuringPour();
    }
    if (MediaQuery.of(context).disableAnimations) {
      _finishReducedMotionPendingResult();
    }
  }

  void _applyPendingResultDuringPour() {
    final item = _pendingResultItem;
    final pendingItem = _activeRevealItem;
    if (item == null ||
        pendingItem == null ||
        _pendingResultApplied ||
        !_samePlot(pendingItem, item)) {
      return;
    }
    setState(() {
      _pendingResultApplied = true;
      _activeRevealItem = item;
      _activeRevealKey = item.revealKey;
    });
    _playRevealResult(item);
  }

  void _finishReducedMotionPendingResult() {
    final item = _pendingResultItem;
    if (item == null || !_pendingScoringWatering) return;
    setState(() {
      _pendingScoringWatering = false;
      _scoringWaitCardVisible = false;
      _wateringVisible = false;
    });
    _startReveal(item);
  }

  void _startReveal(GardenGrowthRevealItem item) {
    _cancelRevealTimers();
    final token = ++_revealToken;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    setState(() {
      _activeRevealKey = item.revealKey;
      _activeRevealItem = item;
      _spotlightCenter = null;
      _spotlightRadius = 0.62;
      _wateringSpread = 24;
      _spotlightVisible = false;
      _wateringVisible = false;
      _pendingScoringWatering = false;
      _scoringWaitCardVisible = false;
      _cyclePourPeakReached = false;
      _pendingResultApplied = false;
      _pendingResultItem = null;
      _wateringCycle = 0;
      _cardVisible = false;
      _revealCtaReady = false;
      _revealAdvancing = false;
      _revealZoeMode = ZoeMascotMode.listening;
      _poppingSkillId = null;
    });
    if (item.quickHello) {
      // No spotlight, no watering can, no scroll-to-plant — just fade the card
      // in over the plain black overlay (rendered while the card is visible).
      _afterReveal(reducedMotion ? 0 : 600, () {
        if (token == _revealToken) _onWateringDone();
      });
      return;
    }
    _afterReveal(
      reducedMotion ? 0 : 300,
      () => unawaited(_focusRevealPlant(item, token)),
    );
  }

  Future<void> _focusRevealPlant(
    GardenGrowthRevealItem item,
    int token, {
    bool pending = false,
  }) async {
    final focusKey = item.wateringOnly
        ? _skillPlotAnchorKeys[item.skillId]
        : _skillAnchorKeys[item.skillId];
    final anchorContext = focusKey?.currentContext;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (anchorContext != null) {
      await Scrollable.ensureVisible(
        anchorContext,
        alignment: item.wateringOnly ? 0.30 : 0.48,
        duration: Duration(milliseconds: reducedMotion ? 0 : 400),
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted || token != _revealToken) return;
    await Future<void>.delayed(Duration(milliseconds: reducedMotion ? 0 : 50));
    if (!mounted || token != _revealToken) return;

    final focus = _focusForReveal(item);
    final center = focus.center;
    setState(() {
      _spotlightCenter = center;
      _spotlightRadius = focus.radius;
      _wateringSpread = focus.wateringSpread;
      _spotlightVisible = true;
      // Every reveal begins on the right. Pending scoring alternates only after
      // a complete cycle; _WateringCan clamps edge plots into the viewport.
      _wateringFromLeft = false;
      // Under reduced motion the can is skipped entirely; otherwise the
      // _WateringCan drives _onWateringPourPeak / _onWateringDone. The plant
      // does NOT pop yet — the growth pop is triggered mid-pour.
      _wateringVisible = !reducedMotion;
    });

    if (reducedMotion) {
      if (pending) {
        _afterReveal(2000, () {
          if (_pendingScoringWatering && _pendingResultItem == null) {
            setState(() => _scoringWaitCardVisible = true);
          }
        });
        return;
      }
      // No pour visuals: fall straight through the pour-peak → done steps.
      _onWateringPourPeak();
      _onWateringDone();
    }
  }

  // Fires mid-pour, as the first droplets reach the plant. For a growth reveal
  // this triggers the plant's pop (_Plant reads _poppingSkillId) and plays the
  // growth sfx; for a watering-only reveal it plays a gentle water sound and
  // leaves the plant untouched.
  void _onWateringPourPeak() {
    final item = _activeRevealItem;
    if (item == null) return;
    _cyclePourPeakReached = true;
    if (_pendingScoringWatering) {
      if (_pendingResultItem != null) {
        _applyPendingResultDuringPour();
      } else {
        unawaited(ref.read(audioProvider).playSfx(Sounds.sprout));
      }
      return;
    }
    _playRevealResult(item);
  }

  void _playRevealResult(GardenGrowthRevealItem item) {
    if (item.wateringOnly) {
      unawaited(ref.read(audioProvider).playSfx(Sounds.sprout));
      return;
    }
    final isBloom = item.toStage == GardenGrowthStage.bloomed;
    setState(() => _poppingSkillId = item.skillId);
    unawaited(
      ref.read(audioProvider).playSfx(isBloom ? Sounds.bloom : Sounds.sprout),
    );
  }

  // Fires when the pour finishes: bring in Zoe's card, then ready the CTA.
  void _onWateringDone() {
    if (_pendingScoringWatering) {
      _onPendingWateringCycleDone();
      return;
    }
    _showRevealCardAfterWatering();
  }

  void _onPendingWateringCycleDone() {
    if (!mounted) return;
    _cyclePourPeakReached = false;
    final result = _pendingResultItem;
    final pendingItem = _activeRevealItem;
    if (result != null && pendingItem != null) {
      if (_samePlot(pendingItem, result)) {
        if (!_pendingResultApplied) _applyPendingResultDuringPour();
        setState(() {
          _pendingScoringWatering = false;
          _scoringWaitCardVisible = false;
          _wateringVisible = false;
          _activeRevealItem = result;
          _activeRevealKey = result.revealKey;
        });
        _showRevealCardAfterWatering();
      } else {
        setState(() {
          _pendingScoringWatering = false;
          _scoringWaitCardVisible = false;
          _wateringVisible = false;
        });
        _startReveal(result);
      }
      return;
    }

    setState(() {
      _wateringCycle += 1;
      _wateringFromLeft = _wateringCycle.isOdd;
      _scoringWaitCardVisible = true;
      // The changed cycle key restarts the complete two-second choreography.
      _wateringVisible = true;
    });
  }

  void _showRevealCardAfterWatering() {
    final token = _revealToken;
    if (!mounted) return;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    setState(() {
      _cardVisible = true;
      _revealZoeMode = ZoeMascotMode.listening;
    });
    _afterReveal(reducedMotion ? 0 : 400, () {
      if (token == _revealToken) _markRevealCtaReady();
    });
  }

  ({Offset center, double radius, double wateringSpread}) _focusForReveal(
    GardenGrowthRevealItem item,
  ) {
    final focusKey = item.wateringOnly
        ? _skillPlotAnchorKeys[item.skillId]
        : _skillAnchorKeys[item.skillId];
    final anchorContext = focusKey?.currentContext;
    final rootBox = context.findRenderObject() as RenderBox?;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    if (rootBox == null || anchorBox == null || !anchorBox.hasSize) {
      final size = MediaQuery.sizeOf(context);
      return (
        center: Offset(size.width / 2, size.height * 0.37),
        radius: item.wateringOnly ? 0.9 : 0.62,
        wateringSpread: item.wateringOnly ? 180 : 24,
      );
    }
    final global = anchorBox.localToGlobal(anchorBox.size.center(Offset.zero));
    final center = rootBox.globalToLocal(global);
    if (!item.wateringOnly) {
      return (center: center, radius: 0.62, wateringSpread: 24);
    }
    final globalLeft = anchorBox.localToGlobal(
      Offset(0, anchorBox.size.height / 2),
    );
    final globalRight = anchorBox.localToGlobal(
      Offset(anchorBox.size.width, anchorBox.size.height / 2),
    );
    final plotWidth =
        (rootBox.globalToLocal(globalRight).dx -
                rootBox.globalToLocal(globalLeft).dx)
            .abs();
    return (
      center: center,
      radius: 0.9,
      wateringSpread: math.min(220.0, plotWidth * 0.78),
    );
  }

  void _markRevealCtaReady() {
    if (_revealCtaReady) return;
    setState(() {
      _revealCtaReady = true;
      _revealZoeMode = ZoeMascotMode.listening;
    });
  }

  void _onRevealCta() {
    if (_revealAdvancing) return;
    final queue = ref.read(gardenGrowthRevealProvider);
    if (queue.isEmpty) return;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    setState(() {
      _revealAdvancing = true;
      _cardVisible = false;
      _revealCtaReady = false;
      _wateringVisible = false;
      _poppingSkillId = null;
    });
    _afterReveal(reducedMotion ? 0 : 240, () {
      final controller = ref.read(gardenGrowthRevealProvider.notifier);
      if (queue.length <= 1) {
        controller.clear();
      } else {
        controller.consumeCurrent();
      }
    });
  }

  void _onExploreCompletedPreviousGarden(String viewedLevel) {
    try {
      ref.read(ttsProvider).stop();
    } catch (_) {}
    ref.read(completedGardenIntroSeenProvider.notifier).markSeen(viewedLevel);
  }

  void _resetRevealLayer() {
    _cancelRevealTimers();
    _revealToken++;
    setState(() {
      _activeRevealKey = null;
      _activeRevealItem = null;
      _spotlightCenter = null;
      _spotlightRadius = 0.62;
      _wateringSpread = 24;
      _spotlightVisible = false;
      _wateringVisible = false;
      _pendingScoringWatering = false;
      _scoringWaitCardVisible = false;
      _cyclePourPeakReached = false;
      _pendingResultApplied = false;
      _pendingResultItem = null;
      _wateringCycle = 0;
      _cardVisible = false;
      _revealCtaReady = false;
      _revealAdvancing = false;
      _revealZoeMode = ZoeMascotMode.listening;
      _poppingSkillId = null;
    });
  }

  @override
  void dispose() {
    _cancelRevealTimers();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final revealQueue = ref.watch(gardenGrowthRevealProvider);
    final postConversation = ref.watch(postConversationGardenRevealProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncRevealState(revealQueue, postConversation);
    });
    // The student's actual current level (drives the "You're here" chip).
    final currentLevel = data.level;
    // The level being *viewed* — may be overridden when the student taps an
    // unlocked garden in the switcher.
    final viewedLevel = (postConversation != null || revealQueue.isNotEmpty)
        ? currentLevel
        : (ref.watch(selectedGardenLevelProvider) ?? currentLevel);
    final completedPreviousActive =
        postConversation == null &&
        revealQueue.isEmpty &&
        isViewingCompletedPreviousGarden(
          currentLevel: currentLevel,
          viewedLevel: viewedLevel,
        );
    final GardenData displayData;
    if (completedPreviousActive) {
      // Real per-level garden from the API. On any failure (network, level
      // mismatch, empty units) show the standard toast and bounce back to
      // the current garden.
      ref.listen(previousGardenProvider(viewedLevel), (prev, next) {
        if (next.hasError && !(prev?.hasError ?? false) && mounted) {
          debugPrint('[Garden] previous garden load error: ${next.error}');
          showEllaErrorToast(context);
          ref.read(selectedGardenLevelProvider.notifier).state = null;
        }
      });
      final previousAsync = ref.watch(previousGardenProvider(viewedLevel));
      final previous = previousAsync.valueOrNull;
      if (previous != null) {
        displayData = previous;
      } else if (previousAsync.isLoading) {
        return const MascotLoadingScreen(message: 'Preparing your garden...');
      } else {
        // Error: keep the current garden on screen until the listener above
        // resets the selection.
        displayData = data;
      }
    } else {
      displayData = data;
    }
    final completedIntroSeen = ref.watch(completedGardenIntroSeenProvider);
    final completedIntroPending =
        completedPreviousActive && !completedIntroSeen.loaded;
    final completedIntroActive =
        completedPreviousActive &&
        completedIntroSeen.loaded &&
        !completedIntroSeen.contains(viewedLevel);
    final spec = _visualSpecFor(viewedLevel);
    final media = MediaQuery.of(context);
    final childName =
        ref.watch(onboardingProvider).valueOrNull?.name?.trim() ?? '';
    final titleName = _gardenOwnerFirstName(childName);
    final levelName = _isKnownGardenLevel(viewedLevel)
        ? spec.label
        : _gardenDisplayName(displayData, spec);
    final scrollClipTop = spec.hillTop + 8;
    final revealLayerActive =
        revealQueue.isNotEmpty || _activeRevealItem != null;
    final modalLayerActive =
        revealLayerActive || completedIntroPending || completedIntroActive;
    final activeGrownSkillIds = <String>{?_poppingSkillId};

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: _GardenBackdrop(
              key: ValueKey('garden-backdrop-${spec.code}'),
              spec: spec,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: scrollClipTop,
          bottom: 0,
          child: RepaintBoundary(
            child: _HillClippedScroll(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  top: math.max(
                    0.0,
                    media.padding.top + _scrollStartY - scrollClipTop,
                  ),
                  bottom: media.padding.bottom + _ctaFadeHeight + 32,
                ),
                child: displayData.steps.isEmpty
                    ? const _EmptyGardenState()
                    : Column(
                        children: [
                          for (var i = 0; i < displayData.steps.length; i++)
                            _GardenUnitRow(
                              data: displayData,
                              step: displayData.steps[i],
                              index: i,
                              spec: spec,
                              grownSkillIds: activeGrownSkillIds,
                              skillAnchorFor: _skillAnchorKeyFor,
                              plotAnchorKey: _plotAnchorKeyFor(
                                displayData.steps[i],
                              ),
                              isPreviousGarden: completedPreviousActive,
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: RepaintBoundary(
            child: _PinnedGardenHeader(
              spec: spec,
              levelName: levelName,
              gardenTitle: "$titleName's Garden",
              scrollProgress: (_scrollOffset / 88).clamp(0.0, 1.0),
              soundOn: widget.soundOn,
              onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
              onToggleSound: widget.onToggleSound,
              onLevelTap: () => _showGardenSwitcherSheet(
                currentLevel: currentLevel,
                ownerFirstName: titleName,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: Duration(
                milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 450,
              ),
              child: widget.showTalkBar && !modalLayerActive
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
        ),
        if (revealLayerActive)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('garden-growth-reveal-blocker'),
              behavior: HitTestBehavior.opaque,
              onTap: () {},
            ),
          ),
        // Quick-hello has no spotlight cut-out — the card reads on a plain,
        // calm black field instead (fades in with the card).
        if (_activeRevealItem?.quickHello ?? false)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                key: const ValueKey('garden-quick-hello-overlay'),
                opacity: _cardVisible ? 0.62 : 0,
                duration: Duration(
                  milliseconds: media.disableAnimations ? 0 : 500,
                ),
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              key: const ValueKey('garden-growth-spotlight-layer'),
              opacity: _spotlightVisible ? 1 : 0,
              duration: Duration(
                milliseconds: media.disableAnimations ? 0 : 500,
              ),
              child: SpotlightOverlay(
                pixelCenter: _spotlightCenter,
                radius: _spotlightRadius,
                figmaStyle: true,
                intensity: SpotlightIntensity.strong,
              ),
            ),
          ),
        ),
        if (_wateringVisible && _spotlightCenter != null)
          Positioned.fill(
            child: IgnorePointer(
              child: _WateringCan(
                // Re-keyed per reveal so the animation restarts on the next
                // plant instead of reusing the previous can's state.
                key: ValueKey(
                  'garden-watering-${_wateringFromLeft ? 'left' : 'right'}-'
                  '$_wateringCycle-${_activeRevealKey ?? ''}',
                ),
                pixelCenter: _spotlightCenter!,
                fromLeft: _wateringFromLeft,
                targetSpread: _wateringSpread,
                scale: (media.size.width / _designWidth)
                    .clamp(0.86, 1.08)
                    .toDouble(),
                reducedMotion: media.disableAnimations,
                onPourPeak: _onWateringPourPeak,
                onDone: _onWateringDone,
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              key: const ValueKey('garden-scoring-wait-card-opacity'),
              opacity: _scoringWaitCardVisible ? 1 : 0,
              duration: Duration(
                milliseconds: media.disableAnimations ? 0 : 240,
              ),
              child: _GardenScoringWaitCard(
                reducedMotion: media.disableAnimations,
              ),
            ),
          ),
        ),
        if (_activeRevealItem != null)
          Positioned.fill(
            child: _GardenGrowthRevealLayer(
              item: _activeRevealItem!,
              visible: _cardVisible,
              ctaReady: _revealCtaReady,
              hasNext: revealQueue.length > 1,
              zoeMode: _revealZoeMode,
              spotlightCenter: _spotlightCenter,
              onCta: _onRevealCta,
            ),
          ),
        if (completedIntroActive)
          Positioned.fill(
            child: _CompletedPreviousGardenIntroLayer(
              levelLabel: levelName,
              onExplore: () => _onExploreCompletedPreviousGarden(viewedLevel),
            ),
          ),
      ],
    );
  }
}

String _gardenOwnerFirstName(String rawName) {
  final trimmed = rawName.trim();
  if (trimmed.isEmpty) return 'Narendra';
  return trimmed.split(RegExp(r'\s+')).first;
}

class _HillClippedScroll extends StatelessWidget {
  final Widget child;
  const _HillClippedScroll({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white, Colors.white],
          stops: [0, 0.12, 1],
        ).createShader(rect),
        child: child,
      ),
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
            for (var i = 0; i < spec.stars.length; i++)
              Positioned(
                left: spec.stars[i].left * scale,
                top: spec.stars[i].top * scale,
                child: _GardenStar(
                  key: ValueKey('garden-star-${spec.code}-$i'),
                  size: spec.stars[i].size * scale,
                ),
              ),
            if (sun != null)
              Positioned(
                left: sun.left * scale,
                top: sun.top * scale,
                child: _GardenSun(spec: sun, size: sun.size * scale),
              ),
            if (spec.clouds == _GardenClouds.left ||
                spec.clouds == _GardenClouds.both)
              Positioned(
                top: MediaQuery.of(context).padding.top + 104,
                left: 0,
                child: _DriftingCloud(
                  key: const ValueKey('garden-cloud-left-motion'),
                  side: 'left',
                  width: _cloudW,
                  screenWidth: constraints.maxWidth,
                  movesRight: true,
                  duration: const Duration(seconds: 42),
                  phase: 0.08,
                ),
              ),
            if (spec.clouds == _GardenClouds.both)
              Positioned(
                top: MediaQuery.of(context).padding.top + 102,
                left: 0,
                child: _DriftingCloud(
                  key: const ValueKey('garden-cloud-right-motion'),
                  side: 'right',
                  width: _cloudW,
                  screenWidth: constraints.maxWidth,
                  movesRight: false,
                  duration: const Duration(seconds: 46),
                  phase: 0.20,
                ),
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

class _GardenStar extends StatelessWidget {
  final double size;
  const _GardenStar({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
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
  final VoidCallback? onLevelTap;

  const _PinnedGardenHeader({
    required this.spec,
    required this.levelName,
    required this.gardenTitle,
    required this.scrollProgress,
    required this.soundOn,
    required this.onBack,
    required this.onToggleSound,
    required this.onLevelTap,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final rowTop = top + _headerTopGap;
    final titleTargetY = rowTop + _levelPillH + 16;
    final titleStartY = top + 84;
    final progress = scrollProgress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleW = math.min(constraints.maxWidth - 32, 386.0);
        final titleTop = lerpDouble(titleStartY, titleTargetY, progress)!;
        final titleSize = lerpDouble(18, 16, progress)!;
        final pillMaxW = math.max(180.0, constraints.maxWidth - 128);

        return SizedBox(
          height: top + _pinnedSkyHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: rowTop,
                child: SizedBox(
                  height: _levelPillH,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: _headerSidePadding,
                          ),
                          child: _HeaderCircleButton(
                            onTap: onBack,
                            icon: Icons.arrow_back_rounded,
                            fill: EllaColors.greenLight,
                            iconColor: EllaColors.greenDeep,
                            border: EllaColors.greenDeep,
                          ),
                        ),
                      ),
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: pillMaxW),
                          child: _LevelSelectorPill(
                            levelName: levelName,
                            iconAsset: spec.iconAsset,
                            onTap: onLevelTap,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: _HeaderCircleButton(
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: (constraints.maxWidth - titleW) / 2,
                top: titleTop,
                width: titleW,
                child: Text(
                  key: const ValueKey('garden-title'),
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
                      color: spec.titleColor,
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
  final VoidCallback? onTap;
  const _LevelSelectorPill({
    required this.levelName,
    required this.iconAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      height: _levelPillH,
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
            iconAsset,
            key: const ValueKey('garden-level-selector-icon'),
            width: 24,
            height: 24,
          ),
          const SizedBox(width: 12),
          Flexible(
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
    return Semantics(
      key: const ValueKey('garden-level-selector'),
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : withTapClick(onTap!),
        child: pill,
      ),
    );
  }
}

// ── Garden switcher sheet ────────────────────────────────────────────────────
// Bottom sheet opened by tapping the level pill. A wooden signpost header with
// Zoe perched in front of it, followed by one card per garden the student has
// reached, plus a single fogged "next garden" card. Tapping an unlocked card
// switches the viewed garden; tapping the fog card pops a Zoe bubble.

const Color _signpostTop = Color(0xFFC49050);
const Color _signpost28 = Color(0xFF9B6828);
const Color _signpost55 = Color(0xFFB08040);
const Color _signpost78 = Color(0xFF966828);
const Color _signpostBottom = Color(0xFF8A5712);
const Color _signpostPeg = Color(0xFF5A3A18);
const Color _switcherCardBorder = Color(0xFF9DB8AE);
// Muted grey-green dashed border for the locked/fog "next garden" card.
const Color _switcherLockedBorder = Color(0xFFBFC9C4);
const Color _bubbleBorder = Color(0xFFD5E7DF);

class _GardenSwitcherSheet extends ConsumerStatefulWidget {
  final String currentLevel;
  final String ownerFirstName;

  const _GardenSwitcherSheet({
    required this.currentLevel,
    required this.ownerFirstName,
  });

  @override
  ConsumerState<_GardenSwitcherSheet> createState() =>
      _GardenSwitcherSheetState();
}

class _GardenSwitcherSheetState extends ConsumerState<_GardenSwitcherSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bubbleController;
  Timer? _bubbleTimer;
  String? _bubbleGardenName; // non-null while the bubble is showing

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _bubbleController.dispose();
    super.dispose();
  }

  void _showBubble(String currentGardenName) {
    _bubbleTimer?.cancel();
    setState(() => _bubbleGardenName = currentGardenName);
    _bubbleController.forward(from: 0);
    _bubbleTimer = Timer(const Duration(milliseconds: 4200), _dismissBubble);
  }

  void _dismissBubble() {
    _bubbleTimer?.cancel();
    if (_bubbleGardenName == null) return;
    setState(() => _bubbleGardenName = null);
  }

  void _onUnlockedTap(String code) {
    ref.read(selectedGardenLevelProvider.notifier).state = code;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reducedMotion = media.disableAnimations;
    final entries = gardenSwitcherEntries(widget.currentLevel);
    final currentEntry = entries.firstWhere(
      (e) => e.isCurrent,
      orElse: () => entries.first,
    );
    final signpostLabel = widget.ownerFirstName.isEmpty
        ? 'Your Gardens'
        : "${widget.ownerFirstName}'s Gardens";

    final content = Column(
      key: const ValueKey('garden-switcher-sheet'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _GardenSignpostHeader(
          label: signpostLabel,
          reducedMotion: reducedMotion,
          // Bubble sits above the signpost Zoe.
          bubble: _bubbleGardenName == null
              ? null
              : _ZoeGardenBubble(
                  controller: _bubbleController,
                  maxWidth: media.size.width - 48,
                ),
        ),
        const SizedBox(height: 16),
        for (final entry in entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _GardenSwitcherCard(
              entry: entry,
              reducedMotion: reducedMotion,
              onTap: entry.isLocked
                  ? () => _showBubble(currentEntry.label)
                  : () => _onUnlockedTap(entry.code),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );

    return SafeArea(
      child: GestureDetector(
        // Tapping anywhere in the sheet (outside the bubble/cards) dismisses
        // the bubble, matching the "tap elsewhere" spec.
        behavior: HitTestBehavior.opaque,
        onTap: _dismissBubble,
        // Centered vertically; a scroll view inside Center only actually
        // scrolls when the content exceeds the viewport (tiny screens),
        // otherwise all gardens show centered without scrolling.
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: 20 + media.padding.bottom),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _GardenSignpostHeader extends StatelessWidget {
  final String label;
  final bool reducedMotion;
  final Widget? bubble;

  const _GardenSignpostHeader({
    required this.label,
    required this.reducedMotion,
    this.bubble,
  });

  @override
  Widget build(BuildContext context) {
    const headerHeight = 176.0;
    const signpostTop = 120.0;
    // Raised so Zoe's base clears the signboard text.
    const zoeTop = signpostTop - 54.0;
    const bubbleGap = 10.0;
    // Stack order matters: the signpost paints first, Zoe paints above it, and
    // the bubble is anchored above Zoe so it never covers her face.
    return SizedBox(
      height: headerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Wooden signpost pill.
          Positioned(
            top: signpostTop,
            left: 24,
            right: 24,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                key: const ValueKey('garden-switcher-sign-board'),
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _signpostTop,
                      _signpost28,
                      _signpost55,
                      _signpost78,
                      _signpostBottom,
                    ],
                    stops: [0, 0.28, 0.55, 0.78, 1],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x522B1D12), // rgba(43,29,18,0.32)
                      offset: Offset(0, 5),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _SignpostPeg(),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: EllaFonts.body(
                          const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.6,
                            letterSpacing: 0.4,
                            color: Color(0xFFFFFCF7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const _SignpostPeg(),
                  ],
                ),
              ),
            ),
          ),
          // Zoe perched on top of the signpost, painted in front of it.
          Positioned(
            top: zoeTop,
            child: ZoeMascot(
              key: const ValueKey('garden-switcher-zoe'),
              mode: ZoeMascotMode.listening,
              size: 64,
              reducedMotion: reducedMotion,
            ),
          ),
          if (bubble != null)
            Positioned(
              bottom: headerHeight - zoeTop + bubbleGap,
              left: 0,
              right: 0,
              child: Align(alignment: Alignment.bottomCenter, child: bubble),
            ),
        ],
      ),
    );
  }
}

class _SignpostPeg extends StatelessWidget {
  const _SignpostPeg();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: _signpostPeg,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _GardenSwitcherCard extends StatefulWidget {
  final GardenSwitcherEntry entry;
  final bool reducedMotion;
  final VoidCallback onTap;

  const _GardenSwitcherCard({
    required this.entry,
    required this.reducedMotion,
    required this.onTap,
  });

  @override
  State<_GardenSwitcherCard> createState() => _GardenSwitcherCardState();
}

class _GardenSwitcherCardState extends State<_GardenSwitcherCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudge;

  @override
  void initState() {
    super.initState();
    _nudge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Locked cards nudge sideways before running their (bubble) action.
    if (widget.entry.isLocked && !widget.reducedMotion) {
      _nudge.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final spec = _visualSpecFor(entry.code);

    final card = Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(20),
        // Locked card's border is drawn by the DottedBorder wrapper below;
        // keep the Container border off so there's no solid line under the dashes.
        border: entry.isLocked
            ? const Border.fromBorderSide(BorderSide.none)
            : Border.all(color: _switcherCardBorder, width: 1),
      ),
      child: Row(
        children: [
          SvgPicture.asset(spec.iconAsset, width: 48, height: 48),
          const SizedBox(width: 12),
          // Name + chip claim all the slack so the chevron always pins to the
          // far right. The chip sits outside the Flexible so it never truncates.
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EllaFonts.body(
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.6,
                        letterSpacing: 0.016,
                        color: EllaColors.ink,
                      ),
                    ),
                  ),
                ),
                if (entry.isCurrent) ...[
                  const SizedBox(width: 8),
                  const _YoureHereChip(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 24,
            color: entry.isLocked
                ? EllaColors.textSecondary
                : EllaColors.greenDeep,
          ),
        ],
      ),
    );

    Widget content = card;
    if (entry.isLocked) {
      content = DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(20),
        color: _switcherLockedBorder,
        strokeWidth: 1.5,
        dashPattern: const [5, 4],
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            card,
            // Fog paints on top of the card content but must not eat the tap —
            // the GestureDetector below still receives it.
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _FogOverlay(
                    key: const ValueKey('garden-switcher-fog'),
                    reducedMotion: widget.reducedMotion,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _nudge,
      builder: (context, child) {
        final dx = _nudge.isAnimating || _nudge.value > 0
            ? _nudgeOffset(_nudge.value)
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Semantics(
        button: true,
        label: entry.isLocked ? '${entry.label} (locked)' : entry.label,
        child: GestureDetector(
          key: ValueKey('garden-switcher-card-${entry.code}'),
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: content,
        ),
      ),
    );
  }

  // −3 → +3 → 0 over the tween.
  double _nudgeOffset(double t) {
    if (t <= 0.5) return -3 + (6 * (t / 0.5));
    return 3 - (3 * ((t - 0.5) / 0.5));
  }
}

class _YoureHereChip extends StatelessWidget {
  const _YoureHereChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garden-switcher-youre-here'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: EllaColors.greenLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        "You're here",
        style: EllaFonts.body(
          const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: EllaColors.greenDeep,
          ),
        ),
      ),
    );
  }
}

// Three stacked fog layers over the next-garden card. Two mist blobs drift
// horizontally on independent long loops (11s / 9s). Frozen when motion is off.
class _FogOverlay extends StatefulWidget {
  final bool reducedMotion;

  const _FogOverlay({super.key, required this.reducedMotion});

  @override
  State<_FogOverlay> createState() => _FogOverlayState();
}

class _FogOverlayState extends State<_FogOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _blobA;
  late final AnimationController _blobB;

  @override
  void initState() {
    super.initState();
    _blobA = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    );
    _blobB = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );
    if (!widget.reducedMotion) {
      _blobA.repeat(reverse: true);
      _blobB.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blobA.dispose();
    _blobB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          children: [
            // Layer 1 — base wash, left → right.
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0x59F4FAF7), // rgba(244,250,247,0.35)
                      Color(0x99F4FAF7), // 0.6 @55%
                      Color(0xCCF4FAF7), // 0.8 @100%
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            // Layer 2 — mist blob A (upper), drifts ±4.5% of row width.
            AnimatedBuilder(
              animation: _blobA,
              builder: (context, _) {
                final drift =
                    (widget.reducedMotion ? 0.0 : (_blobA.value * 2 - 1)) *
                    (w * 0.045);
                return Positioned(
                  left: -w * 0.15 + drift,
                  right: -w * 0.15 - drift,
                  top: 0,
                  bottom: 0,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.2, -0.1),
                        radius: 0.7,
                        colors: [
                          Color(0xD9FFFFFF), // 0.85
                          Color(0xB3FFFFFF), // 0.7
                          Color(0x00FFFFFF),
                        ],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Layer 3 — mist blob B (lower half), drifts the other way.
            AnimatedBuilder(
              animation: _blobB,
              builder: (context, _) {
                final drift =
                    (widget.reducedMotion ? 0.0 : (_blobB.value * 2 - 1)) *
                    (w * 0.05);
                return Positioned(
                  left: -w * 0.15 - drift,
                  right: -w * 0.15 + drift,
                  top: null,
                  bottom: 0,
                  height: constraints.maxHeight * 0.55,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.25, 0.4),
                        radius: 0.7,
                        colors: [
                          Color(0xA6FFFFFF), // 0.65
                          Color(0x00FFFFFF),
                        ],
                        stops: [0, 1],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// Zoe's nudge bubble — "Keep practising to unlock the next garden."
class _ZoeGardenBubble extends StatelessWidget {
  final AnimationController controller;
  final double maxWidth;

  const _ZoeGardenBubble({
    required this.controller,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    final scale = Tween<double>(begin: 0.9, end: 1.0).animate(fade);
    final rise = Tween<double>(begin: 6, end: 0).animate(fade);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Opacity(
          opacity: fade.value,
          child: Transform.translate(
            offset: Offset(0, rise.value),
            child: Transform.scale(scale: scale.value, child: child),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          key: const ValueKey('garden-switcher-bubble'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EllaColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _bubbleBorder, width: 2),
          ),
          child: Text.rich(
            const TextSpan(
              text: 'Keep practising to unlock the next garden.',
            ),
            textAlign: TextAlign.center,
            style: EllaFonts.body(
              const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: EllaColors.greenDeep,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DriftingCloud extends StatefulWidget {
  final String side;
  final double width;
  final double screenWidth;
  final bool movesRight;
  final Duration duration;
  final double phase;

  const _DriftingCloud({
    super.key,
    required this.side,
    required this.width,
    required this.screenWidth,
    required this.movesRight,
    required this.duration,
    required this.phase,
  });

  @override
  State<_DriftingCloud> createState() => _DriftingCloudState();
}

class _DriftingCloudState extends State<_DriftingCloud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _drift.stop();
      _drift.value = 0;
      return;
    }
    if (!_drift.isAnimating) _drift.repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (_, child) {
        final progress = (_drift.value + widget.phase) % 1.0;
        final start = -widget.width;
        final end = widget.screenWidth + widget.width;
        final x = widget.movesRight
            ? lerpDouble(start, end, progress)!
            : lerpDouble(end, start, progress)!;
        return Transform.translate(offset: Offset(x, 0), child: child);
      },
      child: SvgPicture.asset(
        key: ValueKey('garden-cloud-${widget.side}'),
        'assets/gardent-view/clouds-weather.svg',
        width: widget.width,
      ),
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
  final GlobalKey Function(String skillId) skillAnchorFor;
  final GlobalKey plotAnchorKey;
  final bool isPreviousGarden;
  const _GardenUnitRow({
    required this.data,
    required this.step,
    required this.index,
    required this.spec,
    required this.grownSkillIds,
    required this.skillAnchorFor,
    required this.plotAnchorKey,
    this.isPreviousGarden = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / _designWidth).clamp(0.86, 1.10);
        final leftInset = (constraints.maxWidth - _designWidth * scale) / 2;
        final plotOnLeft = index.isEven;
        final signName = step.displayName;
        const signW = _boulderWidth;
        const signH = _boulderHeight;
        final signX = spec.sideProp == _GardenSideProp.lantern && !plotOnLeft
            ? 76.0
            : (plotOnLeft ? _designWidth - 40 - signW : 27.0);
        final signY = 5.0;
        final plotX = plotOnLeft ? 40.0 : 101.0;
        final plotY = signH > 48 ? 103.0 : (plotOnLeft ? 83.0 : 76.0);
        final fenceX = plotOnLeft
            ? 47.0
            : 390.0 - _fenceRunSize(spec.fenceCount, !plotOnLeft).width;
        final fenceY = _fenceTopFor(spec.fenceCount, plotOnLeft: plotOnLeft);
        final sidePropOffset = _sidePropOffsetFor(
          spec,
          plotOnLeft: plotOnLeft,
          plotY: plotY,
          signX: signX,
          signY: signY,
          signW: signW,
          signH: signH,
        );
        final ambientOffset = _ambientOffsetFor(
          spec,
          index: index,
          plotOnLeft: plotOnLeft,
          plotX: plotX,
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
                          left: signX,
                          top: signY,
                          child: _UnitBoulder(
                            key: ValueKey('garden-unit-sign-${step.step}'),
                            name: signName,
                            width: signW,
                            height: signH,
                            iconAsset: _stoneIconFor(step.icon),
                            onTap: () => showUnitSheet(
                              context,
                              data,
                              step,
                              isPreviousGarden: isPreviousGarden,
                            ),
                          ),
                        ),
                        Positioned(
                          left: plotX,
                          top: plotY,
                          child: _Plot(
                            key: ValueKey('garden-plot-${step.step}'),
                            data: data,
                            step: step,
                            spec: spec,
                            grownSkillIds: grownSkillIds,
                            skillAnchorFor: skillAnchorFor,
                            plotAnchorKey: plotAnchorKey,
                            isPreviousGarden: isPreviousGarden,
                          ),
                        ),
                        Positioned(
                          left: fenceX,
                          top: fenceY,
                          child: _FenceRun(
                            leansRight: !plotOnLeft,
                            count: spec.fenceCount,
                            levelCode: spec.code,
                            rowIndex: index,
                          ),
                        ),
                        Positioned(
                          left: sidePropOffset.dx,
                          top: sidePropOffset.dy,
                          // Decorative: must never intercept taps meant for
                          // the tiles/boulder underneath.
                          child: IgnorePointer(child: _SideProp(spec: spec)),
                        ),
                        if (step.hasGrowth || index < 4)
                          Positioned(
                            left: ambientOffset.dx,
                            top: ambientOffset.dy,
                            // Decorative: the creature hovers over the tile
                            // lattice and must never swallow tile taps.
                            child: IgnorePointer(
                              child: _AmbientCreature(kind: spec.ambientKind),
                            ),
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

double _fenceTopFor(int count, {required bool plotOnLeft}) {
  if (plotOnLeft) return 245.0;
  if (count >= 10) return 192.0;
  if (count >= 8) return 233.0;
  if (count >= 6) return 231.0;
  if (count >= 5) return 255.0;
  if (count >= 4) return 239.0;
  return 235.0;
}

Offset _sidePropOffsetFor(
  _GardenLevelVisualSpec spec, {
  required bool plotOnLeft,
  required double plotY,
  required double signX,
  required double signY,
  required double signW,
  required double signH,
}) {
  if (spec.sideProp == _GardenSideProp.lantern) {
    final size = _sidePropSize(spec.sideProp);
    final signCenterY = signY + signH / 2;
    return Offset(
      plotOnLeft ? signX - size.width + 12 : signX - size.width + 24,
      signCenterY - size.height / 2,
    );
  }
  final oldOffset = switch (spec.sideProp) {
    _GardenSideProp.grassTuft => Offset(
      plotOnLeft ? 334.0 : 56.0,
      plotOnLeft ? plotY + 124.0 : 247.0,
    ),
    _GardenSideProp.wildflowers =>
      spec.code == 'A1'
          ? (plotOnLeft ? const Offset(348, 211) : const Offset(59, 242))
          : (plotOnLeft ? const Offset(356, 171) : const Offset(46, 216)),
    _GardenSideProp.mushrooms =>
      spec.code == 'B2'
          ? (plotOnLeft ? const Offset(360, 176) : const Offset(53, 187))
          : (plotOnLeft ? const Offset(358, 193) : const Offset(45, 226)),
    _GardenSideProp.lantern => Offset.zero,
  };
  final oldSize = _sidePropBaseSize(spec.sideProp);
  final newSize = _sidePropSize(spec.sideProp);
  return Offset(
    oldOffset.dx + oldSize.width / 2 - newSize.width / 2,
    oldOffset.dy + oldSize.height - newSize.height,
  );
}

Size _sidePropBaseSize(_GardenSideProp prop) => switch (prop) {
  _GardenSideProp.grassTuft => const Size(24, 30),
  _GardenSideProp.wildflowers => const Size(36, 31),
  _GardenSideProp.mushrooms => const Size(36, 28),
  _GardenSideProp.lantern => const Size(31, 38),
};

Size _sidePropSize(_GardenSideProp prop) => switch (prop) {
  _GardenSideProp.grassTuft => const Size(112, 140),
  _GardenSideProp.wildflowers => const Size(156, 135),
  _GardenSideProp.mushrooms => const Size(156, 120),
  _GardenSideProp.lantern => const Size(135, 165),
};

Offset _ambientOffsetFor(
  _GardenLevelVisualSpec spec, {
  required int index,
  required bool plotOnLeft,
  required double plotX,
  required double plotY,
}) {
  Offset overPlot(double x, double y) => Offset(plotX + x, plotY + y);
  if (spec.code == 'B1') {
    return plotOnLeft ? overPlot(132, 36) : overPlot(122, 48);
  }
  if (spec.code == 'B2') {
    return plotOnLeft ? overPlot(128, 38) : overPlot(132, 48);
  }
  if (spec.code == 'C1') {
    return plotOnLeft ? overPlot(126, 38) : overPlot(132, 48);
  }
  switch (spec.ambientKind) {
    case _GardenAmbientKind.butterfly:
      return plotOnLeft ? overPlot(118, 34) : overPlot(124, 48);
    case _GardenAmbientKind.goldenButterfly:
    case _GardenAmbientKind.firefly:
      return plotOnLeft ? overPlot(132, 36) : overPlot(122, 48);
    case _GardenAmbientKind.bird:
      // Sits on the circular base (was near the fences at y+126).
      return plotOnLeft ? overPlot(104, 96) : overPlot(96, 96);
    case _GardenAmbientKind.bee:
      return plotOnLeft ? overPlot(130, 34) : overPlot(136, 48);
  }
}

/// The boulder base is a fixed size so it sits consistently in the scene and
/// stays proportionate to the garden tiles (unlike the old adaptive signpost).
/// The SVG viewBox is 210×142 (aspect ≈ 1.48).
const double _boulderWidth = 164;
const double _boulderHeight = _boulderWidth / 1.48; // ≈ 111

/// Resolves the stone-styled unit icon from the colored [icon] path
/// (e.g. `…/u1-globe.svg` → `…/u1-globe-stone.svg`).
String _stoneIconFor(String icon) {
  if (icon.isEmpty || icon.contains('-stone.svg')) return icon;
  return icon.replaceFirst('.svg', '-stone.svg');
}

class _UnitBoulder extends StatelessWidget {
  final String name;
  final double width;
  final double height;
  final String iconAsset;
  final VoidCallback onTap;
  const _UnitBoulder({
    super.key,
    required this.name,
    required this.width,
    required this.height,
    required this.iconAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The readable flat top face of the boulder sits within the central band.
    // Keep the icon + engraved text inside this safe area so nothing spills
    // past the stone's silhouette.
    final safeTextWidth = width * 0.66;

    return GestureDetector(
      onTap: withTapClick(onTap),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: SvgPicture.asset(
                'assets/garden/props/boulder-base.svg',
                fit: BoxFit.contain,
              ),
            ),
            Column(
              key: const ValueKey('garden-unit-sign-content'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconAsset.isNotEmpty) ...[
                  _EngravedIcon(
                    key: const ValueKey('garden-unit-sign-icon'),
                    asset: iconAsset,
                    size: 24,
                  ),
                  const SizedBox(height: 3),
                ],
                SizedBox(
                  width: safeTextWidth,
                  child: _BoulderLabel(
                    key: const ValueKey('garden-unit-sign-label'),
                    text: name,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoulderLabel extends StatelessWidget {
  final String text;

  const _BoulderLabel({super.key, required this.text});

  static const double _maxFontSize = 14;
  static const double _minFontSize = 9.5;
  static const int _maxLines = 3;

  TextStyle _style(double fontSize) {
    return EllaFonts.body(
      TextStyle(
        fontSize: fontSize,
        height: 1.12,
        fontWeight: FontWeight.w700,
        color: EllaColors.textSecondary,
        shadows: const [
          // Light lower "lip" gives the letters a carved,
          // engraved-into-the-stone relief.
          Shadow(
            color: Color(0x66FFFFFF),
            offset: Offset(0, 1),
            blurRadius: 0.5,
          ),
        ],
      ),
    );
  }

  double _fittingFontSize(BuildContext context, double maxWidth) {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    for (
      var fontSize = _maxFontSize;
      fontSize >= _minFontSize;
      fontSize -= 0.5
    ) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: _style(fontSize)),
        maxLines: _maxLines,
        textAlign: TextAlign.center,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      if (!painter.didExceedMaxLines) return fontSize;
    }
    return _minFontSize;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = _fittingFontSize(context, constraints.maxWidth);
        return Text(
          text,
          textAlign: TextAlign.center,
          maxLines: _maxLines,
          softWrap: true,
          style: _style(fontSize),
        );
      },
    );
  }
}

/// Renders a boulder unit-sign icon so it reads as carved into the stone rather
/// than sitting on top of it. The icon keeps its own colours; a dark inset copy
/// offset upward makes its top edge recede, and a light lip copy offset downward
/// (the same `0x66FFFFFF` highlight the engraved label uses) fakes the lower rim
/// of a chiselled groove.
class _EngravedIcon extends StatelessWidget {
  final String asset;
  final double size;
  const _EngravedIcon({super.key, required this.asset, required this.size});

  // Matches the label's engraved lip so icon and text relief read identically.
  static const Color _lip = Color(0x66FFFFFF);
  // Sits against the stone's flat top face (≈ #C9C2B0/#DCD6C6); a soft dark
  // tint gives the top edge a recessed shadow.
  static const Color _inset = Color(0x40000000);

  Widget _silhouette(Color color, Offset offset) {
    return Transform.translate(
      offset: offset,
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _silhouette(_inset, const Offset(0, -1)),
          _silhouette(_lip, const Offset(0, 1)),
          SvgPicture.asset(asset, width: size, height: size),
        ],
      ),
    );
  }
}

class _FenceRun extends StatelessWidget {
  final bool leansRight;
  final int count;
  final String levelCode;
  final int rowIndex;
  const _FenceRun({
    required this.leansRight,
    required this.count,
    required this.levelCode,
    required this.rowIndex,
  });

  @override
  Widget build(BuildContext context) {
    final positions = _fenceOffsets(count, leansRight);
    final size = _fenceRunSize(count, leansRight);
    return SizedBox(
      key: ValueKey('garden-fence-run-$levelCode-$rowIndex-$count'),
      width: size.width,
      height: size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < positions.length; i++)
            Positioned(
              left: positions[i].dx,
              top: positions[i].dy,
              child: SizedBox(
                key: ValueKey('garden-fence-$levelCode-$rowIndex-$i'),
                width: _fenceSegmentW,
                height: _fenceSegmentH,
                child: SvgPicture.asset(
                  'assets/garden/props/fence-segment.svg',
                  fit: BoxFit.fill,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<Offset> _fenceOffsets(int count, bool leansRight) {
  final normalized = count.clamp(3, 10).toInt();
  if (leansRight) {
    return switch (normalized) {
      10 => const [
        Offset(0, 0),
        Offset(26, 32),
        Offset(42, 60),
        Offset(89, 72),
        Offset(141, 84),
        Offset(189, 84),
        Offset(236, 84),
        Offset(284, 75),
        Offset(332, 66),
        Offset(379, 45),
      ],
      9 => const [
        Offset(0, 15),
        Offset(47, 27),
        Offset(99, 39),
        Offset(147, 39),
        Offset(194, 39),
        Offset(242, 30),
        Offset(290, 21),
        Offset(337, 0),
        Offset(361, -32),
      ],
      8 => const [
        Offset(0, 15),
        Offset(47, 27),
        Offset(99, 39),
        Offset(147, 39),
        Offset(194, 39),
        Offset(242, 30),
        Offset(290, 21),
        Offset(337, 0),
      ],
      7 => const [
        Offset(0, 27),
        Offset(52, 39),
        Offset(100, 39),
        Offset(147, 39),
        Offset(195, 30),
        Offset(243, 21),
        Offset(290, 0),
      ],
      6 => const [
        Offset(0, 39),
        Offset(48, 39),
        Offset(95, 39),
        Offset(143, 30),
        Offset(191, 21),
        Offset(238, 0),
      ],
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
    10 => const [
      Offset(0, 0),
      Offset(47, 12),
      Offset(99, 24),
      Offset(147, 24),
      Offset(194, 24),
      Offset(242, 15),
      Offset(290, 6),
      Offset(337, -15),
      Offset(361, -47),
      Offset(385, -79),
    ],
    9 => const [
      Offset(0, 0),
      Offset(47, 12),
      Offset(99, 24),
      Offset(147, 24),
      Offset(194, 24),
      Offset(242, 15),
      Offset(290, 6),
      Offset(337, -15),
      Offset(361, -47),
    ],
    8 => const [
      Offset(0, 0),
      Offset(47, 12),
      Offset(99, 24),
      Offset(147, 24),
      Offset(194, 24),
      Offset(242, 15),
      Offset(290, 6),
      Offset(337, -15),
    ],
    7 => const [
      Offset(0, 0),
      Offset(47, 12),
      Offset(99, 24),
      Offset(147, 24),
      Offset(194, 24),
      Offset(242, 15),
      Offset(290, 6),
    ],
    6 => const [
      Offset(0, 0),
      Offset(47, 12),
      Offset(99, 24),
      Offset(147, 24),
      Offset(194, 24),
      Offset(242, 15),
    ],
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
  return Size(maxX + _fenceSegmentW, maxY + _fenceSegmentH);
}

class _SideProp extends StatelessWidget {
  final _GardenLevelVisualSpec spec;
  const _SideProp({required this.spec});

  @override
  Widget build(BuildContext context) {
    final size = _sidePropSize(spec.sideProp);
    final key = ValueKey('garden-side-prop-${spec.code}-${spec.sideProp.name}');
    switch (spec.sideProp) {
      case _GardenSideProp.grassTuft:
        return SizedBox(
          key: key,
          width: size.width,
          height: size.height,
          child: SvgPicture.asset(
            'assets/garden/ambient/grass-tuft.svg',
            fit: BoxFit.contain,
          ),
        );
      case _GardenSideProp.wildflowers:
        return SizedBox(
          key: key,
          width: size.width,
          height: size.height,
          child: SvgPicture.asset(
            'assets/garden/ambient/wildflowers.svg',
            fit: BoxFit.contain,
          ),
        );
      case _GardenSideProp.mushrooms:
        return SizedBox(
          key: key,
          width: size.width,
          height: size.height,
          child: SvgPicture.asset(
            'assets/garden/ambient/mushrooms.svg',
            fit: BoxFit.contain,
          ),
        );
      case _GardenSideProp.lantern:
        return SizedBox(
          key: key,
          width: size.width,
          height: size.height,
          child: SvgPicture.asset(
            'assets/garden/ambient/lantern.svg',
            fit: BoxFit.contain,
          ),
        );
    }
  }
}

// ── Plot: turf-shadow ellipse + tile + bush + plants + butterfly ──────────────

class _Plot extends StatefulWidget {
  final GardenData data;
  final GardenStep step;
  final _GardenLevelVisualSpec spec;
  final Set<String> grownSkillIds;
  final GlobalKey Function(String skillId) skillAnchorFor;
  final GlobalKey plotAnchorKey;
  final bool isPreviousGarden;
  const _Plot({
    super.key,
    required this.data,
    required this.step,
    required this.spec,
    required this.grownSkillIds,
    required this.skillAnchorFor,
    required this.plotAnchorKey,
    this.isPreviousGarden = false,
  });

  @override
  State<_Plot> createState() => _PlotState();
}

class _PlotState extends State<_Plot> {
  // Skill whose tile is currently held down; that tile (and its plant) dip a
  // few px so the child sees exactly which tile they hit.
  String? _pressedSkillId;
  // A tap plays the full dip choreography (down → spring back) before the
  // skill sheet opens, so the feedback is always visible.
  Timer? _tapSequenceTimer;
  bool _tapSequenceRunning = false;

  void _setPressed(String skillId, bool pressed) {
    final next = pressed
        ? skillId
        : (_pressedSkillId == skillId ? null : _pressedSkillId);
    if (next == _pressedSkillId) return;
    setState(() => _pressedSkillId = next);
  }

  void _handleTileTap(String skillId, VoidCallback openSheet) {
    if (_tapSequenceRunning) return;
    _tapSequenceRunning = true;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (reducedMotion) {
      setState(() => _pressedSkillId = null);
      _tapSequenceRunning = false;
      openSheet();
      return;
    }
    // Hold the dip long enough to land, release, let it spring back, then
    // open the sheet.
    setState(() => _pressedSkillId = skillId);
    _tapSequenceTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _pressedSkillId = null);
      _tapSequenceTimer = Timer(const Duration(milliseconds: 130), () {
        _tapSequenceRunning = false;
        if (mounted) openSheet();
      });
    });
  }

  @override
  void dispose() {
    _tapSequenceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skills = widget.step.skills;
    final tileSpots = _tileSpotsFor(skills.length);

    // Paint back-to-front (higher = further back) so front tiles/plants overlap
    // the ones behind them correctly on the isometric lattice.
    final order = List<int>.generate(skills.length, (i) => i)
      ..sort((a, b) => tileSpots[a].top.compareTo(tileSpots[b].top));

    // Per-plant sway stagger: delay = (gridX + gridY) × 400ms, matching the
    // grove animation handoff. Mirrors the lattice layout in _tileSpotsFor.
    final cols = math.max(1, math.sqrt(skills.length).ceil());

    return SizedBox(
      key: widget.plotAnchorKey,
      width: _plotW,
      height: _plotH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Turf shadow disc.
          Positioned(top: 9, left: 0, child: const _GardenPlate()),
          // Bush resting inside the turf-shadow ellipse (front-left).
          Positioned(
            top: 66,
            left: 20,
            child: _PlotBush(tint: widget.spec.bushTint),
          ),
          for (final i in order)
            _SkillTile(
              skill: skills[i],
              spot: tileSpots[i],
              pressed: _pressedSkillId == skills[i].id,
              onPressChanged: (pressed) =>
                  _setPressed(skills[i].id, pressed),
              onTap: () => _handleTileTap(
                skills[i].id,
                () => showSkillSheet(
                  context,
                  widget.step,
                  skills[i],
                  isPreviousGarden: widget.isPreviousGarden,
                ),
              ),
            ),
          for (final i in order)
            if (skills[i].sightings >= 1)
              _SkillPlant(
                skill: skills[i],
                spot: tileSpots[i],
                swayDelayMs: ((i % cols) + (i ~/ cols)) * 400,
                animateGrowth: widget.grownSkillIds.contains(skills[i].id),
                anchorKey: widget.skillAnchorFor(skills[i].id),
                pressed: _pressedSkillId == skills[i].id,
              ),
        ],
      ),
    );
  }
}

class _GardenPlate extends StatelessWidget {
  const _GardenPlate();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('garden-plate'),
      width: _ellipseW,
      height: _ellipseH,
      decoration: BoxDecoration(
        color: const Color(0xFFD2E4A8),
        borderRadius: BorderRadius.all(
          Radius.elliptical(_ellipseW / 2, _ellipseH / 2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB1D28C).withValues(alpha: 0.95),
            offset: const Offset(0, 8.5),
            blurRadius: 3.8,
          ),
        ],
      ),
    );
  }
}

class _PlotBush extends StatelessWidget {
  final Color? tint;
  const _PlotBush({required this.tint});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/gardent-view/bush.svg',
      width: 45,
      height: 31.5,
      colorFilter: tint == null
          ? null
          : ColorFilter.mode(tint!, BlendMode.modulate),
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

// How far a held tile (and its plant) sinks while the finger is down.
const double _tilePressDip = 7.0;

/// Press feedback shared by the tile and its plant: dips [_tilePressDip] px
/// down while [pressed], springing back on release/cancel.
class _TilePressDip extends StatelessWidget {
  final bool pressed;
  final Widget child;
  const _TilePressDip({required this.pressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedContainer(
      duration: Duration(milliseconds: reducedMotion ? 0 : 100),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, pressed ? _tilePressDip : 0, 0),
      child: child,
    );
  }
}

/// Restricts hit testing to the tile's visible isometric footprint — the top
/// diamond face plus the front thickness — instead of the full bounding box.
/// Tiles overlap on the lattice (~48×24 spot spacing vs a 105×80 box), so a
/// rectangular hit area lets a front tile's empty corner steal taps from the
/// visible edge of the tile behind it. Rejected taps fall through to the
/// correct tile in the plot Stack.
class _TileFootprintHitBox extends SingleChildRenderObjectWidget {
  const _TileFootprintHitBox({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTileFootprintHitBox();
}

class _RenderTileFootprintHitBox extends RenderProxyBox {
  // Tile SVG geometry (viewBox 105×80): top face is the diamond
  // (52.5,7.5)-(97.5,30)-(52.5,52.5)-(7.5,30); the front thickness extends
  // 18.75px below the lower face edges.
  static const double _faceCenterX = 52.5;
  static const double _faceCenterY = 30;
  static const double _faceHalfW = 45;
  static const double _faceHalfH = 22.5;
  static const double _thickness = 18.75;

  bool _inFootprint(Offset p) {
    if (size.isEmpty) return false;
    final x = p.dx * _tileW / size.width;
    final y = p.dy * _tileH / size.height;
    final u = (x - _faceCenterX).abs() / _faceHalfW;
    if (u > 1) return false;
    final faceTop = _faceCenterY - _faceHalfH * (1 - u);
    final faceBottom = _faceCenterY + _faceHalfH * (1 - u);
    return y >= faceTop && y <= faceBottom + _thickness;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position) || !_inFootprint(position)) return false;
    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) => true;
}

class _SkillTile extends StatelessWidget {
  final GardenSkill skill;
  final _TileSpot spot;
  final bool pressed;
  final ValueChanged<bool> onPressChanged;
  final VoidCallback onTap;
  const _SkillTile({
    required this.skill,
    required this.spot,
    required this.pressed,
    required this.onPressChanged,
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
        onTapDown: (_) => onPressChanged(true),
        // No onTapUp release: a completed tap hands the dip to the plot's tap
        // sequence (dip lands → springs back → sheet opens). Only a cancelled
        // gesture releases here.
        onTapCancel: () => onPressChanged(false),
        onTap: withTapClick(onTap),
        // deferToChild + _TileFootprintHitBox: only the visible isometric
        // footprint is tappable; taps on the empty box corners fall through
        // to the neighbouring tile behind this one.
        behavior: HitTestBehavior.deferToChild,
        child: _TilePressDip(
          pressed: pressed,
          child: _TileFootprintHitBox(
            child: SizedBox(
              width: _tileW,
              height: _tileH,
              child: SvgPicture.asset(tileAsset, fit: BoxFit.fill),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillPlant extends StatelessWidget {
  final GardenSkill skill;
  final _TileSpot spot;
  final int swayDelayMs;
  final bool animateGrowth;
  final Key? anchorKey;
  final bool pressed;
  const _SkillPlant({
    required this.skill,
    required this.spot,
    required this.swayDelayMs,
    required this.animateGrowth,
    this.anchorKey,
    required this.pressed,
  });

  @override
  Widget build(BuildContext context) {
    final plantHeight = _plantHeightFor(skill);
    return Positioned(
      // Anchor by the art's visual base (at _plantBaseYFrac down the box), then
      // apply a small per-stage nudge so each stage reads centered on its tile:
      // the tall bloom is pulled down and the short sprout raised, since pure
      // base-anchoring left bloom floating high and sprout sitting low.
      top:
          spot.top +
          _tileH * _plantBaseFactor -
          plantHeight * _plantBaseYFrac +
          _plantVerticalNudgeFor(skill),
      left: spot.left + _tileW / 2 - _plantSlotW / 2,
      // The plant is invisible to hit testing: every tap falls through to the
      // tile beneath it, so a planted tile is exactly as clickable as an empty
      // one. The plant still dips with its tile via the shared pressed state.
      child: IgnorePointer(
        child: _TilePressDip(
          pressed: pressed,
          child: SizedBox(
            key: anchorKey,
            width: _plantSlotW,
            height: plantHeight,
            child: SizedBox(
              key: ValueKey('garden-plant-slot-${skill.id}'),
              width: _plantSlotW,
              height: plantHeight,
              child: Center(
                child: _Plant(
                  skill: skill,
                  swayDelayMs: swayDelayMs,
                  animateGrowth: animateGrowth,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _plantHeightFor(GardenSkill skill) => switch (skill.sightings) {
  <= 0 => 0,
  1 => 82.5,
  2 => 116.6,
  _ => 150.7,
};

// Small per-stage vertical nudge so each growth stage reads centered on its
// tile (taller stages pulled down, shorter pushed up). Bases intentionally no
// longer align across stages — this matches the desired per-stage centering.
double _plantVerticalNudgeFor(GardenSkill skill) => switch (skill.sightings) {
  <= 0 => 0,
  1 => -12, // sprout: raise
  2 => 0, // bud: centered baseline
  _ => 12, // bloom: lower
};

// Spring-overshoot curve from the grove handoff: cubic-bezier(0.34,1.56,0.64,1).
// Scales past 1.0 before settling, giving the plant a satisfying "pop".
const Cubic _popCurve = Cubic(0.34, 1.56, 0.64, 1.0);

// ── Watering can pour (post-conversation reveal) ────────────────────────────
//
// A one-shot choreography that tilts a watering can in from a top corner and
// rains a few droplets onto the spotlit plant, then lifts back out. Only the
// concept is taken from the garden design artifact; sizing, timing and the
// SVGs (assets/garden/props/watering-can.svg + water-drop.svg) are ours.
//
// The controller runs 0→1 over [_WateringCan.duration]; sub-phases are carved
// out with Intervals:
//   enter  0.00–0.20  can slides + fades in from the corner, upright (400ms)
//   tilt   0.20–0.32  can rotates and settles near the plot (240ms)
//   pour   0.30–0.80  droplets water the full targeted plot (1000ms)
//   exit   0.80–1.00  can un-tilts and lifts back out / fades (400ms)
// onPourPeak fires once at ~0.52 (as the first drops reach the garden); onDone
// fires when the controller completes.
class _WateringCan extends StatefulWidget {
  /// Plant centre in the reveal layer's coordinate space (from
  /// `_centerForAnchor`). The can hovers above-and-to-the-side of this.
  final Offset pixelCenter;

  /// When true the can enters from the top-left and pours rightward (used near
  /// the right screen edge so the can + drops never clip).
  final bool fromLeft;
  final double targetSpread;
  final double scale;
  final bool reducedMotion;
  final VoidCallback onPourPeak;
  final VoidCallback onDone;

  const _WateringCan({
    super.key,
    required this.pixelCenter,
    required this.fromLeft,
    required this.targetSpread,
    required this.scale,
    required this.reducedMotion,
    required this.onPourPeak,
    required this.onDone,
  });

  static const Duration duration = Duration(milliseconds: 2000);

  @override
  State<_WateringCan> createState() => _WateringCanState();
}

class _WateringCanState extends State<_WateringCan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _WateringCan.duration,
  );

  bool _pourFired = false;

  // Phase curves.
  late final Animation<double> _enter = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.20, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tilt = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.20, 0.32, curve: Curves.easeInOut),
  );
  late final Animation<double> _untilt = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.80, 1.0, curve: Curves.easeInOut),
  );
  late final Animation<double> _exit = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.80, 1.0, curve: Curves.easeInCubic),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reducedMotion) {
      // No pour visuals under reduced motion: just fire the callbacks in order.
      widget.onPourPeak();
      widget.onDone();
      return;
    }
    _controller.addListener(_maybeFirePourPeak);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.forward();
  }

  void _maybeFirePourPeak() {
    if (_pourFired || _controller.value < 0.52) return;
    _pourFired = true;
    widget.onPourPeak();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reducedMotion) return const SizedBox.shrink();

    final s = widget.scale;
    final canWidth = 64.0 * s;
    final canHeight = 56.0 * s;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    // The spout tip sits at roughly (9, 9) in the 128×112 viewBox → normalise.
    final spoutTip = Offset(canWidth * (9 / 128), canHeight * (9 / 112));

    // Horizontal side the can pours from. Default top-right (can on the right,
    // tilting left toward the plant); flipped near the right edge.
    final dir = widget.fromLeft ? -1.0 : 1.0;

    // Rest position of the spout tip once tilted: just above the plant, offset
    // slightly to the pour side so the arc of drops lands on the plant centre.
    final tipRestX = widget.pixelCenter.dx + dir * 24 * s;
    final tipRestY = widget.pixelCenter.dy - 82 * s;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final tilt = 0.42 * _tilt.value - 0.42 * _untilt.value;
        // Enter offset: drift in from higher and further into the corner.
        final enterT = 1 - _enter.value;
        final dx = dir * 46 * s * enterT;
        final dy = -40 * s * enterT;
        // Exit lift.
        final exitLift = -34 * s * _exit.value;
        final opacity =
            (_enter.value).clamp(0.0, 1.0) * (1 - _exit.value).clamp(0.0, 1.0);

        // Position so the (rotated) spout tip lands near tipRest.
        final rawTipX = tipRestX + dx;
        final tipY = tipRestY + dy + exitLift;
        final canLeft = (rawTipX - spoutTip.dx)
            .clamp(8.0, math.max(8.0, viewportWidth - canWidth - 8.0))
            .toDouble();
        final tipX = canLeft + spoutTip.dx;
        final canTop = tipY - spoutTip.dy;

        return Stack(
          children: [
            // Droplets fall from the spout tip toward the plant centre.
            ..._buildDrops(
              origin: Offset(tipX, tipY),
              target: widget.pixelCenter,
              targetSpread: widget.targetSpread,
              scale: s,
            ),
            Positioned(
              left: canLeft,
              top: canTop,
              width: canWidth,
              height: canHeight,
              child: Opacity(
                opacity: opacity,
                child: Transform(
                  key: const ValueKey('garden-watering-can-transform'),
                  alignment: Alignment(
                    (spoutTip.dx / canWidth) * 2 - 1,
                    (spoutTip.dy / canHeight) * 2 - 1,
                  ),
                  transform: Matrix4.identity()
                    ..scaleByDouble(widget.fromLeft ? -1.0 : 1.0, 1.0, 1.0, 1.0)
                    // The source art points up-left. Counterclockwise lowers
                    // its spout toward the plot; horizontal mirroring naturally
                    // produces the matching clockwise tilt from the left.
                    ..rotateZ(-tilt),
                  child: SvgPicture.asset(
                    'assets/garden/props/watering-can.svg',
                    key: const ValueKey('garden-watering-can-art'),
                    width: canWidth,
                    height: canHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildDrops({
    required Offset origin,
    required Offset target,
    required double targetSpread,
    required double scale,
  }) {
    // Drops continuously water the plot for the middle second of the sequence.
    const pourStart = 0.30;
    const pourEnd = 0.80;
    final t = _controller.value;
    if (t < pourStart || t > pourEnd) return const [];
    final pourT = ((t - pourStart) / (pourEnd - pourStart)).clamp(0.0, 1.0);

    const dropCount = 7;
    final dropW = 15.0 * scale;
    final dropH = 20.0 * scale;
    final widgets = <Widget>[];
    for (var i = 0; i < dropCount; i++) {
      // Stagger each drop's launch across the pour window.
      final phase = i / dropCount;
      final local = ((pourT - phase) / (1 - phase)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeIn.transform(local);
      // Give every drop its own evenly spaced landing point. Watering-only
      // reveals pass the plot width here, while real growth stays tightly
      // focused on the plant.
      final landingDx = -targetSpread / 2 + targetSpread * i / (dropCount - 1);
      final targetX = target.dx + landingDx;
      final x = origin.dx + (targetX - origin.dx) * eased;
      final y = origin.dy + (target.dy - origin.dy) * eased;
      // Fade out as the drop nears the plant.
      final opacity = (1 - Curves.easeIn.transform(local)) * 0.9 + 0.1;
      widgets.add(
        Positioned(
          left: x - dropW / 2,
          top: y - dropH / 2,
          width: dropW,
          height: dropH,
          child: Opacity(
            opacity: local >= 1 ? 0 : opacity.clamp(0.0, 1.0),
            child: SvgPicture.asset(
              'assets/garden/props/water-drop.svg',
              key: ValueKey('garden-water-drop-$i'),
              width: dropW,
              height: dropH,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

// Idle plant sway: rotation ±4° about the bottom-centre, 2400ms ping-pong.
const double _swayMaxRad = 4.0 * math.pi / 180;

class _Plant extends StatefulWidget {
  final GardenSkill skill;
  final int swayDelayMs;
  final bool animateGrowth;
  const _Plant({
    required this.skill,
    required this.swayDelayMs,
    required this.animateGrowth,
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
    final height = _plantHeightFor(widget.skill);
    final asset = switch (widget.skill.sightings) {
      <= 0 => '',
      1 => widget.skill.strand.seedlingAsset,
      2 => widget.skill.strand.youngAsset,
      _ => widget.skill.strand.bloomAsset,
    };
    if (asset.isEmpty) return const SizedBox.shrink();

    final art = SvgPicture.asset(
      key: ValueKey('garden-plant-art-${widget.skill.id}'),
      asset,
      height: height,
      fit: BoxFit.contain,
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
      _GardenAmbientKind.butterfly => const _FloatingAmbientAsset(
        asset: 'assets/gardent-view/butterfly 1.svg',
        width: 32,
        height: 32,
        flap: true,
      ),
      _GardenAmbientKind.goldenButterfly => const _FloatingAmbientAsset(
        asset: 'assets/garden/ambient/butterfly-golden.svg',
        width: 20,
        height: 20,
        flap: true,
      ),
      _GardenAmbientKind.bird => const _Bird(),
      _GardenAmbientKind.bee => const _Bee(),
      _GardenAmbientKind.firefly => const _FloatingAmbientAsset(
        asset: 'assets/garden/ambient/firefly.svg',
        width: 26,
        height: 31,
        flap: false,
      ),
    };
  }
}

class _FloatingAmbientAsset extends StatefulWidget {
  final String asset;
  final double width;
  final double height;
  final bool flap;

  const _FloatingAmbientAsset({
    required this.asset,
    required this.width,
    required this.height,
    required this.flap,
  });

  @override
  State<_FloatingAmbientAsset> createState() => _FloatingAmbientAssetState();
}

class _FloatingAmbientAssetState extends State<_FloatingAmbientAsset>
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
    if (widget.flap && !_flap.isAnimating) _flap.repeat(reverse: true);
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
        child: widget.flap
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(_flapScale.value, 1.0, 1.0),
                child: child,
              )
            : child,
      ),
      child: SvgPicture.asset(
        widget.asset,
        width: widget.width,
        height: widget.height,
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
      child: SizedBox(
        key: const ValueKey('garden-ambient-bird'),
        width: 76.8,
        height: 64.8,
        child: SvgPicture.asset(
          'assets/garden/ambient/bird.svg',
          fit: BoxFit.contain,
        ),
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

// ── Post-conversation growth reveal ─────────────────────────────────────────

const Color _growthRevealBorder = Color(0xFF5898E0);
const Color _growthRevealSurface = Color(0xFFFFFDF4);
const Color _growthRevealGreen = Color(0xFF185E35);
const Color _growthRevealWoodDark = Color(0xFF8A5712);

class _GardenScoringWaitCard extends StatelessWidget {
  final bool reducedMotion;

  const _GardenScoringWaitCard({required this.reducedMotion});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = media.padding.bottom + 44;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 76, 32, bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: media.size.width - 64),
          child: IntrinsicWidth(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  key: const ValueKey('garden-scoring-wait-card'),
                  padding: const EdgeInsets.fromLTRB(72, 18, 22, 18),
                  decoration: ellaSmoothDecoration(
                    color: _growthRevealSurface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    side: const BorderSide(
                      color: _growthRevealBorder,
                      width: 3,
                    ),
                  ),
                  child: Text(
                    'Zoe is checking what grew…',
                    maxLines: 2,
                    style: EllaFonts.body(
                      const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                        color: _growthRevealGreen,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -6,
                  top: -46,
                  child: ZoeMascot(
                    key: const ValueKey('garden-scoring-wait-zoe'),
                    mode: ZoeMascotMode.thinking,
                    size: 76,
                    reducedMotion: reducedMotion,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GardenGrowthRevealLayer extends StatelessWidget {
  final GardenGrowthRevealItem item;
  final bool visible;
  final bool ctaReady;
  final bool hasNext;
  final ZoeMascotMode zoeMode;
  final Offset? spotlightCenter;
  final VoidCallback onCta;

  const _GardenGrowthRevealLayer({
    required this.item,
    required this.visible,
    required this.ctaReady,
    required this.hasNext,
    required this.zoeMode,
    required this.spotlightCenter,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reducedMotion = media.disableAnimations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final scale = (width / _designWidth).clamp(0.86, 1.08).toDouble();
        double measureQuickHelloLine(String text, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: media.textScaler,
          )..layout();
          return painter.width;
        }

        final quickHelloNaturalWidth =
            math.max(
              measureQuickHelloLine(
                'That was a quick hello 👋',
                EllaFonts.body(
                  const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              measureQuickHelloLine(
                "We can talk more whenever you're ready.",
                EllaFonts.body(
                  const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ) +
            36;
        final cardWidth = item.quickHello
            ? math.min(math.min(quickHelloNaturalWidth, 320.0), width - 64)
            : math.min(382.0, width - 48);
        final cardLeft = (width - cardWidth) / 2;
        final minTop = media.padding.top + 96;
        final estimatedCardHeight = item.quickHello
            ? 116.0
            : math.min(
                324.0,
                math.max(248.0, height - minTop - media.padding.bottom - 132),
              );
        final focusY = spotlightCenter?.dy ?? height * 0.56;
        final maxTop = math.max(
          minTop,
          height - media.padding.bottom - 56 - 324,
        );
        final mascotSize = 72 * scale;

        // Adaptive placement: prefer above the spotlit plant, but if the card
        // plus Zoe's overhang won't fit above it (top garden / top-most plant),
        // drop the card below the plant so it never covers the spotlight.
        const plantClearance = 96.0; // clears the spotlight bright hole
        final zoeOverhang = 58 * scale;
        final desiredAboveTop = focusY - estimatedCardHeight - plantClearance;
        final fitsAbove = desiredAboveTop - zoeOverhang >= minTop;
        final double cardTop;
        if (fitsAbove) {
          cardTop = math.min(math.max(desiredAboveTop, minTop), maxTop);
        } else {
          final belowTop = focusY + plantClearance;
          cardTop = math.min(
            belowTop,
            math.max(minTop, height - media.padding.bottom - 56 - 220),
          );
        }
        final cardMaxHeight = math.max(
          220.0,
          height - cardTop - media.padding.bottom - 112,
        );

        return Stack(
          children: [
            AnimatedOpacity(
              key: const ValueKey('garden-growth-reveal-card-opacity'),
              opacity: visible ? 1 : 0,
              duration: Duration(milliseconds: reducedMotion ? 0 : 320),
              child: AnimatedSlide(
                offset: visible ? Offset.zero : const Offset(0, 0.035),
                duration: Duration(milliseconds: reducedMotion ? 0 : 320),
                curve: Curves.easeOutCubic,
                child: item.wateringOnly && !item.quickHello
                    ? _WateringRevealPresentation(
                        item: item,
                        cardWidth: cardWidth,
                        mascotSize: mascotSize,
                        zoeMode: zoeMode,
                        reducedMotion: reducedMotion,
                      )
                    : Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: cardLeft,
                            top: cardTop,
                            width: cardWidth,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: cardMaxHeight,
                              ),
                              child: _GardenGrowthRevealCard(item: item),
                            ),
                          ),
                          Positioned(
                            left: math.max(16.0, cardLeft - 6 * scale),
                            // Zoe sits ON the card, overlapping its top edge.
                            top: math.max(
                              media.padding.top + 16,
                              cardTop - 58 * scale,
                            ),
                            child: ZoeMascot(
                              key: const ValueKey('garden-growth-reveal-zoe'),
                              mode: zoeMode,
                              size: mascotSize,
                              reducedMotion: reducedMotion,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            AnimatedSwitcher(
              duration: Duration(milliseconds: reducedMotion ? 0 : 260),
              child: ctaReady
                  ? Align(
                      key: ValueKey(
                        'garden-growth-reveal-cta-layer-${hasNext ? 'next' : 'done'}',
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: media.padding.bottom + 22,
                        ),
                        child: _GardenIntroButton(
                          key: const ValueKey('garden-growth-reveal-cta'),
                          label: hasNext ? 'See Next Plant' : 'See My Garden',
                          width: hasNext ? 197 : 202,
                          onTap: onCta,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _WateringRevealPresentation extends StatelessWidget {
  final GardenGrowthRevealItem item;
  final double cardWidth;
  final double mascotSize;
  final ZoeMascotMode zoeMode;
  final bool reducedMotion;

  const _WateringRevealPresentation({
    required this.item,
    required this.cardWidth,
    required this.mascotSize,
    required this.zoeMode,
    required this.reducedMotion,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const cardTopInset = 58.0;
    final topPadding = media.padding.top + 72;
    final bottomPadding = media.padding.bottom + 112;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = math.max(
          0.0,
          constraints.maxHeight - topPadding - bottomPadding,
        );
        return SingleChildScrollView(
          key: const ValueKey('garden-watering-reveal-presentation-scroll'),
          padding: EdgeInsets.fromLTRB(0, topPadding, 0, bottomPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: availableHeight),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: cardWidth,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: cardTopInset),
                      child: _GardenGrowthRevealCard(item: item),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: ZoeMascot(
                        key: const ValueKey('garden-growth-reveal-zoe'),
                        mode: zoeMode,
                        size: mascotSize,
                        reducedMotion: reducedMotion,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GardenGrowthRevealCard extends StatelessWidget {
  final GardenGrowthRevealItem item;
  const _GardenGrowthRevealCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final track = item.skill.strand.track;
    final quote = item.evidence?.quote.trim();

    if (item.quickHello) {
      return _buildQuickHelloCard();
    }
    if (item.wateringOnly) {
      return _buildWateringOnlyCard(quote);
    }

    return Container(
      key: const ValueKey('garden-growth-reveal-card'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      clipBehavior: Clip.antiAlias,
      decoration: ellaSmoothDecoration(
        color: _growthRevealSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        side: const BorderSide(color: _growthRevealBorder, width: 3),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    key: const ValueKey('garden-growth-reveal-title'),
                    _growthRevealTitle(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: EllaFonts.body(
                      const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                        color: _growthRevealGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SvgPicture.asset(
                  _growthStageVisual(item.toStage).asset,
                  width: 24,
                  height: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _RevealSkillIcon(skill: item.skill, size: 48),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.skill.displayText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: EllaFonts.body(
                      const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                        color: EllaColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (item.wateringOnly) ...[
              const _GrowthRevealDivider(),
              const SizedBox(height: 12),
              if (quote != null && quote.isNotEmpty) ...[
                Text(
                  'A sentence you used',
                  style: EllaFonts.body(
                    const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('garden-watering-reveal-note'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: track.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: track.border, width: 2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        'assets/information-box/quote-mark.svg',
                        width: 16,
                        height: 16,
                        colorFilter: ColorFilter.mode(
                          track.text,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          quote,
                          style: EllaFonts.body(
                            TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              fontWeight: FontWeight.w600,
                              color: track.text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Text(
                  key: const ValueKey('garden-watering-reveal-note'),
                  'You practiced this skill with Zoe. Keep watering it — it '
                  'will grow soon!',
                  style: EllaFonts.body(
                    const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.ink,
                    ),
                  ),
                ),
            ] else ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RevealGrowthChip(
                    key: ValueKey('garden-growth-from-${item.fromStage.key}'),
                    stage: item.fromStage,
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: EllaColors.ink,
                  ),
                  const SizedBox(width: 8),
                  _RevealGrowthChip(
                    key: ValueKey('garden-growth-to-${item.toStage.key}'),
                    stage: item.toStage,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _GrowthRevealDivider(),
              const SizedBox(height: 12),
              Text(
                'You Said',
                style: EllaFonts.body(
                  const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: EllaColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('garden-growth-reveal-evidence'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: track.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: track.border, width: 2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      'assets/information-box/quote-mark.svg',
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        track.text,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        quote == null || quote.isEmpty
                            ? 'I practiced this with Zoe.'
                            : quote,
                        style: EllaFonts.body(
                          TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                            color: track.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWateringOnlyCard(String? quote) {
    return Container(
      key: const ValueKey('garden-growth-reveal-card'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      clipBehavior: Clip.antiAlias,
      decoration: ellaSmoothDecoration(
        color: _growthRevealSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        side: const BorderSide(color: _growthRevealBorder, width: 3),
      ),
      child: Column(
        key: const ValueKey('garden-watering-reveal-card'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('garden-growth-reveal-title'),
            'You practised today, and your garden got some water.',
            style: EllaFonts.body(
              const TextStyle(
                fontSize: 16,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: _growthRevealGreen,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Every conversation gives your English a little more life.',
            style: EllaFonts.body(
              const TextStyle(
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: EllaColors.ink,
              ),
            ),
          ),
          if (quote != null && quote.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'A sentence you used',
              style: EllaFonts.body(
                const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: EllaColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('garden-watering-reveal-note'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: ellaSmoothDecoration(
                color: EllaColors.greenLight,
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: EllaColors.greenMain, width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: SvgPicture.asset(
                      'assets/information-box/quote-mark.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                        EllaColors.greenDeep,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      quote,
                      style: EllaFonts.body(
                        const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                          color: EllaColors.greenDeep,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The lighter "quick hello" card: no plant chrome, no skill row — just a
  /// title and a warm one-liner. Shown when a session ended with no growth and
  /// fewer than a few turns (see [GardenGrowthRevealItem.quickHello]).
  Widget _buildQuickHelloCard() {
    return Container(
      key: const ValueKey('garden-quick-hello-card'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      clipBehavior: Clip.antiAlias,
      decoration: ellaSmoothDecoration(
        color: _growthRevealSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        side: const BorderSide(color: _growthRevealBorder, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('garden-quick-hello-title'),
            _growthRevealTitle(item),
            style: EllaFonts.body(
              const TextStyle(
                fontSize: 16,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: _growthRevealGreen,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            key: const ValueKey('garden-quick-hello-note'),
            "We can talk more whenever you're ready.",
            style: EllaFonts.body(
              const TextStyle(
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: EllaColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthRevealDivider extends StatelessWidget {
  const _GrowthRevealDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      width: double.infinity,
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
            _growthRevealWoodDark,
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
    );
  }
}

class _RevealGrowthChip extends StatelessWidget {
  final GardenGrowthStage stage;
  const _RevealGrowthChip({super.key, required this.stage});

  @override
  Widget build(BuildContext context) {
    final visual = _growthStageVisual(stage);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(visual.asset, width: 16, height: 16),
          const SizedBox(width: 4),
          Text(
            stage.label,
            style: EllaFonts.body(
              TextStyle(
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.048,
                color: visual.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealSkillIcon extends StatelessWidget {
  final GardenSkill skill;
  final double size;
  const _RevealSkillIcon({required this.skill, required this.size});

  @override
  Widget build(BuildContext context) {
    final icon = _resolveRevealSkillIcon(skill);
    if (icon.startsWith('http://') || icon.startsWith('https://')) {
      return SvgPicture.network(
        icon,
        width: size,
        height: size,
        placeholderBuilder: (_) =>
            SvgPicture.asset(skill.strand.icon, width: size, height: size),
      );
    }
    return SvgPicture.asset(icon, width: size, height: size);
  }
}

class _RevealGrowthVisual {
  final String asset;
  final Color background;
  final Color text;

  const _RevealGrowthVisual({
    required this.asset,
    required this.background,
    required this.text,
  });
}

_RevealGrowthVisual _growthStageVisual(GardenGrowthStage stage) =>
    switch (stage) {
      GardenGrowthStage.seed => const _RevealGrowthVisual(
        asset: 'assets/information-box/growth-seed.svg',
        background: Color(0xFFE6D3C3),
        text: Color(0xFF9A6A44),
      ),
      GardenGrowthStage.sprout => const _RevealGrowthVisual(
        asset: 'assets/information-box/growth-sprout.svg',
        background: Color(0xFFD7F2C4),
        text: Color(0xFF4E9A45),
      ),
      GardenGrowthStage.budding => const _RevealGrowthVisual(
        asset: 'assets/information-box/growth-budding.svg',
        background: Color(0xFFDDF8E8),
        text: _growthRevealGreen,
      ),
      GardenGrowthStage.bloomed => const _RevealGrowthVisual(
        asset: 'assets/information-box/growth-bloom.svg',
        background: Color(0xFFFFD9E8),
        text: Color(0xFF7B163C),
      ),
    };

String _growthRevealTitle(GardenGrowthRevealItem item) {
  if (item.quickHello) {
    return 'That was a quick hello 👋';
  }
  if (item.wateringOnly) {
    return 'You practised today, and your garden got some water.';
  }
  if (item.toStage == GardenGrowthStage.bloomed) {
    return 'This skill is in full bloom!';
  }
  if (item.fromStage == GardenGrowthStage.seed &&
      item.toStage == GardenGrowthStage.sprout) {
    return 'A new skill is sprouting';
  }
  return 'This skill just grew stronger';
}

String _resolveRevealSkillIcon(GardenSkill skill) {
  final icon = skill.icon.trim();
  if (icon.isEmpty) return skill.strand.icon;
  if (icon.startsWith('assets/') ||
      icon.startsWith('http://') ||
      icon.startsWith('https://')) {
    return icon;
  }
  const aliases = {
    'clock': 'assets/information-box/clock.svg',
    'flower': 'assets/information-box/flower.svg',
    'talk-svgrepo-com': 'assets/information-box/talk-svgrepo-com.svg',
    'people-who-support-svgrepo-com':
        'assets/information-box/people-who-support-svgrepo-com 1.svg',
    'u1-globe': 'assets/information-box/unit-globe.svg',
  };
  return aliases[icon] ?? skill.strand.icon;
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
                      width: 170,
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
                                'Start Talking',
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
