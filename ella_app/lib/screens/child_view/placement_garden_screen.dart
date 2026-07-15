// Placement garden — the Sunrise Seedbed scene used both before and after the
// placement screening. The first-run onboarding reveal stays in this existing
// screen so the garden art, header, spotlight, and bottom CTA have one owner.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ella_smooth_shape.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/placement_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/audio_service.dart';
import '../../services/sounds.dart';
import '../../services/stt_tts_service.dart';
import 'garden_screen.dart';
import 'home_screen.dart' show kHomeChildName;
import 'widgets/garden_sound_button.dart';
import 'widgets/placement_garden_header.dart';
import 'widgets/spotlight_callout_bubble.dart';
import 'widgets/spotlight_overlay.dart';
import 'widgets/zoe_mascot.dart';
import 'chat_bubble.dart';

const String _kVoiceIcon = 'assets/homescreen/new/UserSound.svg';
const String _kBubblePlantIcon = 'assets/homescreen/new/Plant.svg';
const String _kExplorePlantIcon = 'assets/gardent-view/plc_plant.svg';
const String _kFenceIcon = 'assets/garden/plants/fence-segment 8.svg';
const String _kWildflowers = 'assets/garden/plants/wildflowers 2.svg';
const String _kTilledTile = 'assets/garden/tiles/tile-tilled.svg';
const String _kTurfTile = 'assets/garden/tiles/tile-turf.svg';
const String _kPlotShadow = 'assets/gardent-view/Ellipse.svg';
const String _kBush = 'assets/gardent-view/bush.svg';
const String _kPlantBud = 'assets/garden/plants/placement-plant-young.svg';
const String _kPlantBloom = 'assets/garden/plants/placement-plant-bloom.svg';
const String _kFlowerIcon = 'assets/information-box/flower.svg';

const String _kRevealText =
    'Look, your first plant\nEvery conversation grows something new here';
const String _kPlacementBloomText =
    "Your flower is blooming!\nYou've got a brand new garden waiting with space for even more plants";
// Spoken when the child ends the screening early (no level determined): the
// sprout-spotlight nudge that encourages them to talk again.
const String _kPlacementSproutText =
    "Your plant is soaking up sunshine.\nLet's talk again and watch it grow!";

enum PlacementGardenMode {
  /// Post-age onboarding reveal: empty garden, spotlight, Zoe line, Explore,
  /// then the settled garden with a compact "Let's Talk" return to placement
  /// home.
  onboardingReveal,

  /// Placement Home garden shortcut: show the settled placement garden
  /// immediately.
  browse,

  /// Existing post-placement-test branch: wait for level resolution, then let
  /// the child explicitly continue from the seedbed bloom into the real garden.
  placementResult,
}

enum _Phase {
  empty,
  revealSproutHold,
  revealSpotlightOnly,
  reveal,
  exploreReady,
  settled,
  placementSprout,
  placementBloom,
  placementSpotlight,
  // Abandoned-placement branch (End Call before a level is determined):
  // sprout with no CTA for a beat, then a spotlight + speaking nudge + Explore.
  placementSproutHold,
  placementSproutSpotlight,
}

class PlacementGardenScreen extends ConsumerStatefulWidget {
  final PlacementGardenMode mode;

  /// Name/age collected in onboarding. They are passed directly so this route
  /// can complete onboarding even before the async cache write has rebuilt.
  final String? onboardingName;
  final int? onboardingAge;

  /// False when resuming with cached name/age: skip the reveal and show the
  /// settled garden.
  final bool playReveal;

  const PlacementGardenScreen({
    super.key,
    this.mode = PlacementGardenMode.placementResult,
    this.onboardingName,
    this.onboardingAge,
    this.playReveal = true,
  });

  @override
  ConsumerState<PlacementGardenScreen> createState() =>
      _PlacementGardenScreenState();
}

class _PlacementGardenScreenState extends ConsumerState<PlacementGardenScreen>
    with WidgetsBindingObserver {
  late _Phase _phase = switch (widget.mode) {
    PlacementGardenMode.onboardingReveal when !widget.playReveal =>
      _Phase.settled,
    PlacementGardenMode.browse => _Phase.settled,
    PlacementGardenMode.placementResult => _Phase.placementSprout,
    _ => _Phase.empty,
  };

  final List<Timer> _timers = [];
  bool _started = false;
  bool _resolved = false;
  bool _completingOnboarding = false;
  bool _handingOffToGarden = false;
  // True once the sprout nudge line has finished — gates the Explore Garden
  // button so it fades in *after* Zoe speaks (abandoned-placement branch).
  bool _sproutExploreReady = false;
  ZoeMascotMode _zoeMode = ZoeMascotMode.listening;

  late final AudioInterface _audio;

  bool get _isOnboardingReveal =>
      widget.mode == PlacementGardenMode.onboardingReveal;
  bool get _revealSpotlightOn =>
      _phase == _Phase.revealSpotlightOnly ||
      _phase == _Phase.reveal ||
      _phase == _Phase.exploreReady;
  bool get _revealLayerOn =>
      _phase == _Phase.reveal || _phase == _Phase.exploreReady;
  // The sprout spotlight callout (Zoe + nudge bubble) is on during the
  // abandoned-placement spotlight phase.
  bool get _sproutRevealLayerOn => _phase == _Phase.placementSproutSpotlight;
  bool get _placementRevealLayerOn =>
      _phase == _Phase.placementBloom ||
      _phase == _Phase.placementSpotlight ||
      _sproutRevealLayerOn;
  bool get _showExplore => _phase == _Phase.exploreReady;
  bool get _showSeeMyGarden => _phase == _Phase.placementSpotlight;
  // Explore Garden (abandoned branch) shows only after the nudge line lands.
  bool get _showSproutExplore =>
      _phase == _Phase.placementSproutSpotlight && _sproutExploreReady;
  bool get _showSettledBar => _phase == _Phase.settled;
  bool get _showPlant => _phase != _Phase.empty;
  // The sprout phases keep the bud (no bloom grow).
  bool get _showBloom =>
      _phase == _Phase.placementBloom || _phase == _Phase.placementSpotlight;
  bool get _reducedMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  late final TtsInterface _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _audio = ref.read(audioProvider);
    _audio.playMusic(Sounds.gardenMusic);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    switch (widget.mode) {
      case PlacementGardenMode.onboardingReveal:
        if (widget.playReveal) {
          _after(_reducedMotion ? 0 : 1000, _beginOnboardingReveal);
        }
      case PlacementGardenMode.browse:
        break;
      case PlacementGardenMode.placementResult:
        _startPlacementResultBranch();
    }
  }

  void _after(int ms, VoidCallback fn) {
    final timer = Timer(Duration(milliseconds: ms), () {
      if (mounted) fn();
    });
    _timers.add(timer);
  }

  void _startPlacementResultBranch() {
    final known = ref.read(placementProvider).levelAssigned;
    if (known != null) {
      _after(0, () => _onPlacementResolved(known));
      return;
    }
    _after(_reducedMotion ? 500 : 6000, () {
      if (_resolved) return;
      _onPlacementResolved(ref.read(placementProvider).result?.level != null);
    });
  }

  void _onPlacementResolved(bool levelAssigned) {
    if (_resolved) return;
    _resolved = true;
    if (!levelAssigned) {
      // Abandoned placement: show the sprout with no CTA for a beat, then the
      // spotlight nudge that invites the child to talk again.
      setState(() => _phase = _Phase.placementSproutHold);
      _after(_reducedMotion ? 0 : 1000, _beginSproutSpotlight);
      return;
    }
    setState(() => _phase = _Phase.placementSprout);
    _after(_reducedMotion ? 0 : 1000, _beginPlacementBloomReveal);
  }

  void _beginOnboardingReveal() {
    setState(() {
      _phase = _Phase.revealSproutHold;
      _zoeMode = ZoeMascotMode.listening;
    });
    unawaited(_audio.playSfx(Sounds.sprout));

    _after(_reducedMotion ? 0 : 1500, () {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.revealSpotlightOnly;
      });

      _after(_reducedMotion ? 0 : 800, () {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.reveal;
          _zoeMode = ZoeMascotMode.speaking;
        });
        unawaited(_speakRevealAndUnlockExplore());
      });
    });
  }

  void _beginPlacementBloomReveal() {
    if (_phase != _Phase.placementSprout) return;
    setState(() {
      _phase = _Phase.placementBloom;
      _zoeMode = ZoeMascotMode.speaking;
    });
    unawaited(_audio.playSfx(Sounds.level));
    unawaited(_speakPlacementBloomAndUnlockSeeGarden());
  }

  // Abandoned-placement branch: turn on the spotlight + speaking bubble, then
  // (after the line lands) reveal the Explore Garden button.
  void _beginSproutSpotlight() {
    if (_phase != _Phase.placementSproutHold) return;
    setState(() {
      _phase = _Phase.placementSproutSpotlight;
      _zoeMode = ZoeMascotMode.speaking;
    });
    unawaited(_audio.playSfx(Sounds.nudge));
    unawaited(_speakSproutAndUnlockExplore());
  }

  Future<void> _speakRevealAndUnlockExplore() async {
    Timer? fallback;
    fallback = Timer(const Duration(milliseconds: 5200), () {
      if (mounted) _markExploreReady();
    });
    _timers.add(fallback);
    await _speakRevealLine();
    fallback.cancel();
    if (mounted) _markExploreReady();
  }

  Future<void> _speakPlacementBloomAndUnlockSeeGarden() async {
    Timer? fallback;
    fallback = Timer(const Duration(milliseconds: 5600), () {
      if (mounted) _markSeeMyGardenReady();
    });
    _timers.add(fallback);
    await _speakPlacementBloomLine();
    fallback.cancel();
    if (mounted) _markSeeMyGardenReady();
  }

  Future<void> _speakSproutAndUnlockExplore() async {
    Timer? fallback;
    fallback = Timer(const Duration(milliseconds: 5200), () {
      if (mounted) _markSproutExploreReady();
    });
    _timers.add(fallback);
    await _speakSproutLine();
    fallback.cancel();
    if (mounted) _markSproutExploreReady();
  }

  Future<void> _speakRevealLine() async {
    final tts = ref.read(ttsProvider);
    if (tts.isSpeaking) return;
    try {
      await tts.stop();
      if (!mounted) return;
      setState(() => _zoeMode = ZoeMascotMode.speaking);
      await tts.speak(_kRevealText);
    } catch (_) {}
    if (mounted) setState(() => _zoeMode = ZoeMascotMode.listening);
  }

  Future<void> _speakPlacementBloomLine() async {
    final tts = ref.read(ttsProvider);
    if (tts.isSpeaking) return;
    try {
      await tts.stop();
      if (!mounted) return;
      setState(() => _zoeMode = ZoeMascotMode.speaking);
      await tts.speak(_kPlacementBloomText);
    } catch (_) {}
    if (mounted) setState(() => _zoeMode = ZoeMascotMode.listening);
  }

  Future<void> _speakSproutLine() async {
    final tts = ref.read(ttsProvider);
    if (tts.isSpeaking) return;
    try {
      await tts.stop();
      if (!mounted) return;
      setState(() => _zoeMode = ZoeMascotMode.speaking);
      await tts.speak(_kPlacementSproutText);
    } catch (_) {}
    if (mounted) setState(() => _zoeMode = ZoeMascotMode.listening);
  }

  void _markExploreReady() {
    if (_phase != _Phase.reveal) return;
    setState(() {
      _phase = _Phase.exploreReady;
      _zoeMode = ZoeMascotMode.listening;
    });
  }

  void _markSeeMyGardenReady() {
    if (_phase != _Phase.placementBloom) return;
    setState(() {
      _phase = _Phase.placementSpotlight;
      _zoeMode = ZoeMascotMode.listening;
    });
  }

  // Keep the spotlight phase but reveal the Explore Garden button once the
  // nudge line has landed (or the fallback fires).
  void _markSproutExploreReady() {
    if (_phase != _Phase.placementSproutSpotlight || _sproutExploreReady) {
      return;
    }
    setState(() {
      _sproutExploreReady = true;
      _zoeMode = ZoeMascotMode.listening;
    });
  }

  void _onExploreGarden() {
    if (_phase != _Phase.exploreReady) return;
    try {
      _tts.stop();
    } catch (_) {}
    setState(() => _phase = _Phase.settled);
  }

  // Explore Garden (abandoned branch): fade the spotlight/bubble/button out and
  // fade the settled Let's Talk bar in.
  void _onExploreSprout() {
    if (_phase != _Phase.placementSproutSpotlight) return;
    try {
      _tts.stop();
    } catch (_) {}
    setState(() => _phase = _Phase.settled);
  }

  void _onSeeMyGarden() {
    if (_phase != _Phase.placementSpotlight) return;
    try {
      _tts.stop();
    } catch (_) {}
    _toLevelGarden();
  }

  void _toLevelGarden() {
    if (!mounted) return;
    _handingOffToGarden = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          backgroundColor: Colors.transparent,
          body: GardenScreen(firstTime: true),
        ),
      ),
    );
  }

  Future<void> _completeOnboardingAndReturn() async {
    if (_completingOnboarding) return;
    _completingOnboarding = true;
    try {
      await ref.read(ttsProvider).stop();
    } catch (_) {}

    if (_isOnboardingReveal) {
      final name = _resolvedName;
      final age =
          widget.onboardingAge ?? ref.read(onboardingProvider).valueOrNull?.age;
      if (age != null) {
        await ref
            .read(onboardingProvider.notifier)
            .complete(name: name, age: age);
      }
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _handleBack() {
    switch (widget.mode) {
      case PlacementGardenMode.onboardingReveal:
        unawaited(_completeOnboardingAndReturn());
      case PlacementGardenMode.browse:
        Navigator.of(context).maybePop();
      case PlacementGardenMode.placementResult:
        Navigator.of(context).maybePop();
    }
  }

  String get _resolvedName {
    final fromWidget = widget.onboardingName?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    final fromProvider = ref.read(onboardingProvider).valueOrNull?.name?.trim();
    if (fromProvider != null && fromProvider.isNotEmpty) return fromProvider;
    return kHomeChildName;
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
    if (!_handingOffToGarden) _audio.stopMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _audio.stopMusic();
    } else if (state == AppLifecycleState.resumed && mounted) {
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
      if (isCurrent && _audio.musicEnabled) {
        _audio.playMusic(Sounds.gardenMusic);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(placementProvider.select((s) => s.levelAssigned), (_, next) {
      if (widget.mode == PlacementGardenMode.placementResult && next != null) {
        _onPlacementResolved(next);
      }
    });

    final name =
        widget.onboardingName ??
        ref.watch(onboardingProvider).valueOrNull?.name ??
        kHomeChildName;
    final child = Scaffold(
      backgroundColor: const Color(0xFFDDEFE4),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final metrics = _PlacementGardenMetrics.from(
            Size(constraints.maxWidth, constraints.maxHeight),
            media.padding,
          );
          return Stack(
            key: const ValueKey('placement-garden-screen'),
            fit: StackFit.expand,
            children: [
              const RepaintBoundary(child: _PlacementGardenBackdrop()),
              RepaintBoundary(child: _PlacementDecorations(metrics: metrics)),
              Positioned(
                left: metrics.headerPadding,
                right: metrics.headerPadding,
                top: metrics.headerTop,
                child: RepaintBoundary(
                  child: PlacementGardenHeader(
                    name: name,
                    onBack: _handleBack,
                    // Every garden speaker is a mute-only toggle for the ambient
                    // garden music (matches the real garden's speaker button).
                    trailing: const GardenSoundButton(size: 32),
                  ),
                ),
              ),
              Positioned(
                left: (constraints.maxWidth - metrics.plotWidth) / 2,
                top: metrics.plotTop,
                child: RepaintBoundary(
                  child: _PlacementPlot(
                    width: metrics.plotWidth,
                    showPlant: _showPlant,
                    bloom: _showBloom,
                    reducedMotion: _reducedMotion,
                  ),
                ),
              ),
              Positioned(
                left: metrics.fenceLeft,
                right: metrics.fenceRight,
                top: metrics.fenceTop,
                child: RepaintBoundary(
                  child: _PlacementFence(scale: metrics.scale),
                ),
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: (_revealSpotlightOn || _placementRevealLayerOn)
                      ? 1
                      : 0,
                  duration: Duration(milliseconds: _reducedMotion ? 0 : 600),
                  child: RepaintBoundary(
                    child: SpotlightOverlay(
                      center: metrics.spotlightCenter,
                      radius: metrics.spotlightRadius,
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: Duration(milliseconds: _reducedMotion ? 0 : 600),
                child: _revealLayerOn
                    ? _RevealCallout(
                        key: const ValueKey('placement-garden-callout'),
                        metrics: metrics,
                        zoeMode: _zoeMode,
                        reducedMotion: _reducedMotion,
                        bubble: const _RevealBubble(),
                      )
                    : _sproutRevealLayerOn
                    ? _RevealCallout(
                        key: const ValueKey('placement-garden-sprout-callout'),
                        metrics: metrics,
                        zoeMode: _zoeMode,
                        reducedMotion: _reducedMotion,
                        placementStyle: true,
                        bubble: const _PlacementSproutBubble(),
                      )
                    : _placementRevealLayerOn
                    ? _RevealCallout(
                        key: const ValueKey('placement-garden-bloom-callout'),
                        metrics: metrics,
                        zoeMode: _zoeMode,
                        reducedMotion: _reducedMotion,
                        placementStyle: true,
                        bubble: const _PlacementBloomBubble(),
                      )
                    : const SizedBox.shrink(),
              ),
              AnimatedSwitcher(
                duration: Duration(milliseconds: _reducedMotion ? 0 : 450),
                child: _showExplore
                    ? Align(
                        key: const ValueKey('placement-garden-explore-layer'),
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: metrics.bottomSafe + 22,
                          ),
                          child: _SmallBerryButton(
                            key: const ValueKey('placement-garden-explore'),
                            label: 'Explore Garden',
                            width: metrics.exploreWidth,
                            height: 56,
                            leadingAsset: _kExplorePlantIcon,
                            onTap: _onExploreGarden,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              AnimatedSwitcher(
                duration: Duration(milliseconds: _reducedMotion ? 0 : 450),
                child: _showSproutExplore
                    ? Align(
                        key: const ValueKey(
                          'placement-garden-sprout-explore-layer',
                        ),
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: metrics.bottomSafe + 22,
                          ),
                          child: _SmallBerryButton(
                            key: const ValueKey(
                              'placement-garden-sprout-explore',
                            ),
                            label: 'Explore Garden',
                            width: metrics.exploreWidth,
                            height: 56,
                            leadingAsset: _kExplorePlantIcon,
                            onTap: _onExploreSprout,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              AnimatedSwitcher(
                duration: Duration(milliseconds: _reducedMotion ? 0 : 450),
                child: _showSeeMyGarden
                    ? Align(
                        key: const ValueKey('placement-garden-see-layer'),
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: metrics.bottomSafe + 22,
                          ),
                          child: _SmallBerryButton(
                            key: const ValueKey(
                              'placement-garden-see-my-garden',
                            ),
                            label: 'See My Garden',
                            width: metrics.exploreWidth,
                            height: 56,
                            leadingAsset: _kExplorePlantIcon,
                            onTap: _onSeeMyGarden,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              AnimatedSwitcher(
                duration: Duration(milliseconds: _reducedMotion ? 0 : 450),
                child: _showSettledBar
                    ? _SettledTalkBar(
                        key: const ValueKey('placement-garden-settled-layer'),
                        bottomSafe: metrics.bottomSafe,
                        reducedMotion: _reducedMotion,
                        onTalk:
                            widget.mode == PlacementGardenMode.onboardingReveal
                            ? _completeOnboardingAndReturn
                            : () => Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );

    if (!_isOnboardingReveal) return child;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_completeOnboardingAndReturn());
      },
      child: child,
    );
  }
}

class _PlacementGardenMetrics {
  final double scale;
  final double headerPadding;
  final double headerTop;
  final double bottomSafe;
  final double plotWidth;
  final double plotTop;
  final double fenceTop;
  final double fenceLeft;
  final double fenceRight;
  final double bubbleWidth;
  final double bubbleTop;
  final double bubbleLeft;
  final double mascotLeft;
  final double mascotTop;
  final double placementBubbleWidth;
  final double placementBubbleTop;
  final double placementBubbleLeft;
  final double placementMascotLeft;
  final double placementMascotTop;
  final double exploreWidth;
  final Alignment spotlightCenter;
  final double spotlightRadius;

  const _PlacementGardenMetrics({
    required this.scale,
    required this.headerPadding,
    required this.headerTop,
    required this.bottomSafe,
    required this.plotWidth,
    required this.plotTop,
    required this.fenceTop,
    required this.fenceLeft,
    required this.fenceRight,
    required this.bubbleWidth,
    required this.bubbleTop,
    required this.bubbleLeft,
    required this.mascotLeft,
    required this.mascotTop,
    required this.placementBubbleWidth,
    required this.placementBubbleTop,
    required this.placementBubbleLeft,
    required this.placementMascotLeft,
    required this.placementMascotTop,
    required this.exploreWidth,
    required this.spotlightCenter,
    required this.spotlightRadius,
  });

  factory _PlacementGardenMetrics.from(Size size, EdgeInsets padding) {
    final width = size.width;
    final height = size.height;
    final scale = (width / 430).clamp(0.82, 1.08).toDouble();
    final headerPadding = (width * 24 / 430).clamp(16.0, 24.0).toDouble();
    final headerTop = padding.top + 16;
    const headerHeight = 104.0;
    final bottomSafe = padding.bottom;
    final bottomReserve = bottomSafe + 108;

    final plotWidth = (width * 342.98 / 430).clamp(276.0, 343.0).toDouble();
    final plotHeight = plotWidth * 194 / 342.98;
    final idealPlotTop = height * 397 / 932;
    final minPlotTop = headerTop + headerHeight + 116 * scale;
    final maxPlotTop = height - bottomReserve - plotHeight - 36 * scale;
    final plotTop = maxPlotTop < minPlotTop
        ? math.max(headerTop + headerHeight + 78 * scale, maxPlotTop)
        : idealPlotTop.clamp(minPlotTop, maxPlotTop).toDouble();

    final fenceTop = plotTop + plotHeight + 26 * scale;
    // The welcome/reveal bubble spans the full width (24px side margins) — the
    // same wide card as the placement bloom/sprout callouts — so its two-line
    // body never wraps tall enough to reach down over the plant. (Previously it
    // was pinned to 296px, which is the "width won't increase" bug.)
    final bubbleWidth = width - 48;
    final bubbleLeft = 24.0;
    // Keep the bubble's bottom clear of the plant top. The plant draws from
    // ~40px above plotTop (bloom) and the card is ~150px tall, so anchor it high
    // under the header and never let it sink past that gap.
    final maxBubbleTop = plotTop - 170 * scale;
    final minBubbleTop = headerTop + headerHeight + 10;
    final bubbleTop = maxBubbleTop < minBubbleTop
        ? minBubbleTop
        : (height * 200 / 932).clamp(minBubbleTop, maxBubbleTop).toDouble();

    // Spotlight hole centred on the plant (which sits in the upper part of the
    // plot box and, when bloomed, rises ~40px above plotTop). A tight radius keeps
    // the clear circle hugging the plant while the blurred, darkened scrim frames
    // the rest of the garden.
    final spotlightCenterY = plotTop + plotHeight * 0.20;
    final spotlightCenter = Alignment(0, (spotlightCenterY / height) * 2 - 1);
    const spotlightRadius = 0.68;
    // Spotlight bubble spans the full screen width with 24px side padding.
    final placementBubbleLeft = 24.0;
    final placementBubbleWidth = width - 48;
    final placementBubbleTopIdeal = headerTop + 108 * scale;
    final placementBubbleTopMax = math.max(
      headerTop + 104,
      plotTop - 150 * scale,
    );
    final placementBubbleTop = math.min(
      placementBubbleTopIdeal,
      placementBubbleTopMax,
    );
    final placementMascotLeft = math.max(16.0, placementBubbleLeft - 6 * scale);
    // Zoe sits just above the bubble's top border, closer than before.
    // Reduced offset from 76 to 52 to position her lower, sitting just above
    // the spotlight bubble (mascot height 72, with ~20px gap from bubble top).
    final placementMascotTop = math.max(
      headerTop,
      placementBubbleTop - 52 * scale,
    );

    return _PlacementGardenMetrics(
      scale: scale,
      headerPadding: headerPadding,
      headerTop: headerTop,
      bottomSafe: bottomSafe,
      plotWidth: plotWidth,
      plotTop: plotTop,
      fenceTop: fenceTop,
      fenceLeft: (width * 48 / 430).clamp(20.0, 48.0).toDouble(),
      fenceRight: (width * 51 / 430).clamp(20.0, 51.0).toDouble(),
      bubbleWidth: bubbleWidth,
      bubbleTop: bubbleTop,
      bubbleLeft: bubbleLeft,
      mascotLeft: math.max(16, bubbleLeft - 6 * scale),
      mascotTop: math.max(headerTop, bubbleTop - 52 * scale),
      placementBubbleWidth: placementBubbleWidth,
      placementBubbleTop: placementBubbleTop,
      placementBubbleLeft: placementBubbleLeft,
      placementMascotLeft: placementMascotLeft,
      placementMascotTop: placementMascotTop,
      exploreWidth: math.min(204, width - 96),
      spotlightCenter: spotlightCenter,
      spotlightRadius: spotlightRadius,
    );
  }
}

class _PlacementGardenBackdrop extends StatelessWidget {
  const _PlacementGardenBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PlacementGardenBackdropPainter());
  }
}

class _PlacementGardenBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Sky + hills matched to Figma "Morning Meadow" (same values as
    // garden_screen._morningSky / _morningHill): sky #EAFDFF→#D9FAFF→#F1FFF8,
    // hills #D7F2C4→#8DD67C→#4E9A45, stops [0, 0.55, 1].
    final skyRect = Offset.zero & size;
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAFDFF), Color(0xFFD9FAFF), Color(0xFFF1FFF8)],
          stops: [0, 0.55, 1],
        ).createShader(skyRect),
    );

    final sunCenter = Offset(size.width * 0.87, size.height * 0.202);
    final sunRadius = (size.width * 0.085).clamp(28.0, 36.0);
    canvas.drawCircle(
      sunCenter,
      sunRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFF1C5),
            Color(0xFFFFD77A),
            Color(0x66FFD77A),
            Color(0x00FFD77A),
          ],
          stops: [0, 0.36, 0.72, 1],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius)),
    );

    // One rounded green hill mass over the sky (Figma has a single hill
    // gradient from the crest to the bottom). Crest fractions are pushed down
    // ~20% from the Figma values so the sky band reads taller; the hill keeps its
    // shape and simply starts lower.
    final hill = Path()
      ..moveTo(0, size.height * 0.269)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.186,
        size.width * 0.63,
        size.height * 0.204,
        size.width,
        size.height * 0.270,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      hill,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD7F2C4), Color(0xFF8DD67C), Color(0xFF4E9A45)],
              stops: [0, 0.55, 1],
            ).createShader(
              Rect.fromLTWH(
                0,
                size.height * 0.192,
                size.width,
                size.height * 0.808,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlacementDecorations extends StatelessWidget {
  final _PlacementGardenMetrics metrics;
  const _PlacementDecorations({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 34 * metrics.scale,
          top: metrics.plotTop - 82 * metrics.scale,
          child: SvgPicture.asset(_kWildflowers, width: 36 * metrics.scale),
        ),
        Positioned(
          left: 32 * metrics.scale,
          top: metrics.fenceTop + 78 * metrics.scale,
          child: SvgPicture.asset(_kWildflowers, width: 36 * metrics.scale),
        ),
      ],
    );
  }
}

class _PlacementPlot extends StatefulWidget {
  final double width;
  final bool showPlant;
  final bool bloom;
  final bool reducedMotion;

  const _PlacementPlot({
    required this.width,
    required this.showPlant,
    required this.bloom,
    required this.reducedMotion,
  });

  @override
  State<_PlacementPlot> createState() => _PlacementPlotState();
}

class _PlacementPlotState extends State<_PlacementPlot>
    with TickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _growScale = CurvedAnimation(
    parent: _grow,
    curve: Curves.easeOutBack,
  );
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.showPlant || widget.reducedMotion) {
      _grow.value = widget.showPlant ? 1 : 0;
    }
    if (widget.showPlant && !widget.reducedMotion) _sway.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PlacementPlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showPlant && !oldWidget.showPlant) {
      if (widget.reducedMotion) {
        _grow.value = 1;
      } else {
        _grow.forward(from: 0).whenComplete(() {
          if (mounted && widget.showPlant && !widget.reducedMotion) {
            _sway.repeat(reverse: true);
          }
        });
      }
    }
    if (widget.showPlant && widget.bloom && !oldWidget.bloom) {
      if (widget.reducedMotion) {
        _grow.value = 1;
      } else {
        _grow.forward(from: 0.24);
        if (!_sway.isAnimating) _sway.repeat(reverse: true);
      }
    }
    if (!widget.showPlant && oldWidget.showPlant) {
      _sway.stop();
      _grow.value = 0;
    }
    if (widget.reducedMotion && !oldWidget.reducedMotion) {
      _sway.stop();
      if (widget.showPlant) _grow.value = 1;
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width;
    final height = width * 194 / 342.98;
    final tileWidth = width * 183.75 / 342.98;
    final tileTop = width * 40 / 342.98;
    final plantHeight = width * (widget.bloom ? 152 : 112) / 342.98;
    final plantTop = width * (widget.bloom ? -40 : 0) / 342.98;
    final sway = Tween<double>(
      begin: -0.07,
      end: 0.07,
    ).animate(CurvedAnimation(parent: _sway, curve: Curves.easeInOut));

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SvgPicture.asset(_kPlotShadow, width: width),
          ),
          Positioned(
            left: width * 41 / 342.98,
            top: width * 119 / 342.98,
            child: SvgPicture.asset(_kBush, width: width * 46 / 342.98),
          ),
          Positioned(
            top: tileTop,
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: widget.reducedMotion ? 0 : 420),
              child: SvgPicture.asset(
                widget.showPlant ? _kTurfTile : _kTilledTile,
                key: ValueKey(
                  widget.showPlant
                      ? 'placement-garden-turf-tile'
                      : 'placement-garden-tilled-tile',
                ),
                width: tileWidth,
              ),
            ),
          ),
          if (widget.showPlant)
            Positioned(
              top: plantTop,
              child: ScaleTransition(
                scale: _growScale,
                alignment: Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: _sway,
                  builder: (context, child) => Transform.rotate(
                    angle: widget.reducedMotion ? 0 : sway.value,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                  child: SvgPicture.asset(
                    widget.bloom ? _kPlantBloom : _kPlantBud,
                    height: plantHeight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlacementFence extends StatelessWidget {
  final double scale;
  const _PlacementFence({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Transform.translate(
            offset: Offset(
              0,
              (i == 0 || i == 6)
                  ? -8 * scale
                  : (i.isOdd ? 6 * scale : 14 * scale),
            ),
            child: SvgPicture.asset(_kFenceIcon, width: 40 * scale),
          ),
      ],
    );
  }
}

class _RevealCallout extends StatelessWidget {
  final _PlacementGardenMetrics metrics;
  final ZoeMascotMode zoeMode;
  final bool reducedMotion;
  final bool placementStyle;
  final Widget bubble;

  const _RevealCallout({
    super.key,
    required this.metrics,
    required this.zoeMode,
    required this.reducedMotion,
    this.placementStyle = false,
    this.bubble = const _RevealBubble(),
  });

  @override
  Widget build(BuildContext context) {
    final mascotLeft = placementStyle
        ? metrics.placementMascotLeft
        : metrics.mascotLeft;
    final mascotTop = placementStyle
        ? metrics.placementMascotTop
        : metrics.mascotTop;
    final mascotSize = (placementStyle ? 72 : 72) * metrics.scale;
    final bubbleLeft = placementStyle
        ? metrics.placementBubbleLeft
        : metrics.bubbleLeft;
    final bubbleTop = placementStyle
        ? metrics.placementBubbleTop
        : metrics.bubbleTop;
    final bubbleWidth = placementStyle
        ? metrics.placementBubbleWidth
        : metrics.bubbleWidth;
    // Bubble is painted first, then the mascot, so Zoe renders IN FRONT of the
    // bubble (she only overlaps its top-left corner, not the text).
    return Stack(
      children: [
        Positioned(
          left: bubbleLeft,
          top: bubbleTop,
          width: bubbleWidth,
          child: bubble,
        ),
        Positioned(
          left: mascotLeft,
          top: mascotTop,
          child: ZoeMascot(
            mode: zoeMode,
            size: mascotSize,
            reducedMotion: reducedMotion,
          ),
        ),
      ],
    );
  }
}

class _RevealBubble extends StatelessWidget {
  const _RevealBubble();

  @override
  Widget build(BuildContext context) {
    return const SpotlightCalloutBubble(
      key: ValueKey('placement-garden-reveal-bubble'),
      title: 'Look, your first plant',
      body: 'Every conversation grows something new here',
      highlightStart: -1,
      highlightEnd: -1,
    );
  }
}

class _PlacementBloomBubble extends StatelessWidget {
  const _PlacementBloomBubble();

  @override
  Widget build(BuildContext context) {
    final title = 'Your flower is blooming!';
    return Container(
      key: const ValueKey('placement-garden-bloom-bubble'),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: TypewriterText(
                  text: title,
                  style: EllaTextStyles.bodySemiboldLarge.copyWith(
                    color: EllaColors.greenDeep,
                  ),
                  animate: false,
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(_kFlowerIcon, width: 25, height: 24),
            ],
          ),
          const SizedBox(height: 16),
          TypewriterText(
            text:
                "You've got a brand new garden\nwaiting with space for even more\nplants",
            style: EllaTextStyles.bodySemiboldLarge.copyWith(
              color: EllaColors.ink,
            ),
            animate: false,
          ),
        ],
      ),
    );
  }
}

/// Abandoned-placement nudge bubble (Figma frame 598-12759): a Plant icon
/// leading the first line, then the encouragement to talk again. Same shell as
/// the bloom bubble so the two spotlight callouts read consistently.
class _PlacementSproutBubble extends StatelessWidget {
  const _PlacementSproutBubble();

  @override
  Widget build(BuildContext context) {
    final title = 'Your plant is soaking up';
    return Container(
      key: const ValueKey('placement-garden-sprout-bubble'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(_kBubblePlantIcon, width: 24, height: 24),
              const SizedBox(width: 8),
              Flexible(
                child: TypewriterText(
                  text: title,
                  style: EllaTextStyles.bodySemiboldLarge.copyWith(
                    color: EllaColors.greenDeep,
                  ),
                  animate: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TypewriterText(
            text: "sunshine. Let's talk again and\nwatch it grow!",
            style: EllaTextStyles.bodySemiboldLarge.copyWith(
              color: EllaColors.greenDeep,
            ),
            animate: false,
          ),
        ],
      ),
    );
  }
}

class _SmallBerryButton extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final String leadingAsset;
  final VoidCallback onTap;

  const _SmallBerryButton({
    super.key,
    required this.label,
    required this.width,
    required this.height,
    required this.leadingAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Container(
        width: width,
        height: height,
        decoration: ellaSmoothDecoration(
          color: EllaColors.berryMain,
          borderRadius: BorderRadius.circular(999),
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
              leadingAsset,
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

class _SettledTalkBar extends StatelessWidget {
  final double bottomSafe;
  final bool reducedMotion;
  final VoidCallback onTalk;

  const _SettledTalkBar({
    super.key,
    required this.bottomSafe,
    required this.reducedMotion,
    required this.onTalk,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 84 + bottomSafe,
        padding: EdgeInsets.only(bottom: bottomSafe + 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00FFFDF4), Color(0xCCFFFDF4)],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 224,
            height: 64,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: ZoeMascot(
                    mode: ZoeMascotMode.listening,
                    size: 64,
                    reducedMotion: reducedMotion,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _SmallBerryButton(
                    key: const ValueKey('placement-garden-settled-talk'),
                    label: "Let's Talk",
                    width: 154,
                    height: 48,
                    leadingAsset: _kVoiceIcon,
                    onTap: onTalk,
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
