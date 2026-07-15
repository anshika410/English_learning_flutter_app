// Placement intro — the first-run "Homescreen" (Figma "Placement Flow").
// Shown by RootGate before a student has been levelled: the garden sky, Zoe, a
// warm "tell me about yourself" greeting, and a single "Let's Talk" CTA that
// starts the voice placement screening. Mirrors HomeScreen's header (labelled
// Profile/Garden shortcuts) but stays simpler — no topic chips or Last-time
// card, since there's no history or level yet.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/ella_smooth_shape.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../core/offline_alert_popup.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/placement_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/stt_tts_service.dart';
import '../../services/audio_service.dart';
import '../../services/sounds.dart';
import 'home_screen.dart' show kHomeChildName;
import 'placement_garden_screen.dart';
import 'placement_screen.dart';
import 'profile_screen.dart';
import 'widgets/circle_icon_button.dart';
import 'widgets/ella_primary_button.dart';
import 'widgets/garden_sky_background.dart';
import 'widgets/speaker_dot_button.dart';
import 'widgets/zoe_mascot.dart';
import 'dart:async';
import 'chat_bubble.dart';

const String _kVoiceIcon = 'assets/homescreen/new/UserSound.svg';
const String _kPlantIcon = 'assets/homescreen/new/Plant.svg';

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
  // True while the greeting is playing — drives the speaker dot's stop glyph.
  bool _speaking = false;
  int _highlightStart = -1;
  int _highlightEnd = -1;
  StreamSubscription? _ttsProgressSub;
  StreamSubscription? _ttsDoneSub;

  late final TtsInterface _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    final nativeTts = ref.read(nativeTtsProvider);
    _ttsProgressSub = nativeTts.progressStream.listen((event) {
      if (mounted) {
        setState(() {
          _highlightStart = event.start;
          _highlightEnd = event.end;
        });
      }
    });
    _ttsDoneSub = nativeTts.doneStream.listen((_) {
      if (mounted) {
        setState(() {
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
    });
    // Greet the child aloud shortly after the screen appears (waiting for
    // navigation transitions and any prior route's TTS stop() to settle).
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _speakGreeting();
    });
  }

  @override
  void dispose() {
    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
    try {
      _tts.stop();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _speakGreeting() async {
    if (_speaking) return; // prevent concurrent calls
    setState(() {
      _speaking = true;
      _highlightStart = -1;
      _highlightEnd = -1;
    });
    try {
      // speak() awaits real playback completion (awaitSpeakCompletion).
      await ref.read(ttsProvider).speak(_kGreeting);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _speaking = false;
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
    }
  }

  // Speaker dot on the greeting card: replays the greeting when idle. While
  // it's already playing, tapping it stops (mutes) the speech.
  void _toggleSpeak() async {
    if (_speaking) {
      try {
        await _tts.stop();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _speaking = false;
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
    } else {
      _speakGreeting();
    }
  }

  void _startPlacement() {
    final isOnline = ref.read(connectivityProvider).value ?? true;
    if (!isOnline) {
      OfflineAlertPopup.show(context);
      return;
    }
    // Start each screening from a clean slate (a prior End left stale state).
    ref.invalidate(placementProvider);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlacementScreen()));
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          backgroundColor: Colors.transparent,
          body: ProfileScreen(),
        ),
      ),
    );
  }

  // Pre-level, the garden shortcut shows the sprout-state placement garden.
  void _openGarden() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const PlacementGardenScreen(mode: PlacementGardenMode.browse),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mascotW = (size.width * 0.35).clamp(128.0, 168.0);
    // Figma places Zoe ~24% down (y=224/932) with a clear sky band above; a
    // clamped top gap holds that on tall/short phones without re-centering.
    final topGap = (size.height * 0.14).clamp(64.0, 150.0);
    // Prefer the name the child typed during onboarding; fall back to the demo
    // placeholder if it isn't cached yet.
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    final childName =
        ref.watch(onboardingProvider).valueOrNull?.name ?? kHomeChildName;
        
    final greetingText = _kGreeting;

    return GardenSkyBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          // Stack (not a Column) so the mascot + greeting + CTA group sits at
          // the true centre of the screen; the header overlays the top edge.
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top gap seats Zoe ~24% down with a sky band above, per
                      // Figma (top-aligned, not re-centered).
                      SizedBox(height: topGap),
                      ZoeMascot(
                        // Speak the greeting with the speaking animation; fall
                        // back to the calm listening pose when idle.
                        mode: !isOnline
                            ? ZoeMascotMode.sleep
                            : _speaking
                                ? ZoeMascotMode.speaking
                                : ZoeMascotMode.listening,
                        size: mascotW,
                        reducedMotion: MediaQuery.of(context).disableAnimations,
                      ),
                      const SizedBox(height: 10),
                      _GreetingCard(
                        speaking: _speaking,
                        onToggle: _toggleSpeak,
                        highlightStart: _highlightStart,
                        highlightEnd: _highlightEnd,
                        text: greetingText,
                      ),
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
              ),
              // Header mirrors HomeScreen: greeting left, labelled Profile /
              // Garden shortcuts stacked on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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
                  Column(
                    children: [
                      EllaCircleIconButton(
                        glyph: const Icon(
                          Icons.person_rounded,
                          size: 30,
                          color: EllaColors.infoDark,
                        ),
                        fill: EllaColors.surfaceVariant,
                        ring: EllaColors.info,
                        label: 'Profile',
                        labelColor: EllaColors.infoDark,
                        labelStyle: EllaTextStyles.buttonSmall,
                        onTap: _openProfile,
                      ),
                      const SizedBox(height: 12),
                      EllaCircleIconButton(
                        // Garden leaf gently sways (Figma placement intro).
                        glyph: _SwayingLeaf(
                          child: SvgPicture.asset(
                            _kPlantIcon,
                            width: 32,
                            height: 32,
                          ),
                        ),
                        fill: EllaColors.greenLight,
                        ring: EllaColors.greenDark,
                        label: 'Garden',
                        labelColor: EllaColors.greenDeep,
                        labelStyle: EllaTextStyles.buttonSmall,
                        onTap: _openGarden,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final bool speaking;
  final VoidCallback onToggle;
  final int highlightStart;
  final int highlightEnd;
  final String text;

  const _GreetingCard({
    required this.speaking,
    required this.onToggle,
    required this.text,
    this.highlightStart = -1,
    this.highlightEnd = -1,
  });

  @override
  Widget build(BuildContext context) {
    // The 40px dot straddles the card's top-right corner (Figma): it hangs
    // above and off the right edge. Top padding keeps it inside the Stack's
    // hit-test bounds.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: ellaSmoothDecoration(
              color: EllaColors.surface,
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: EllaColors.info, width: 2),
            ),
            child: TypewriterText(
              text: text,
              style: EllaTextStyles.bodySemiboldLarge,
              highlightStart: highlightStart,
              highlightEnd: highlightEnd,
              animate: false,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: -6,
          child: SpeakerDotButton(active: speaking, onTap: onToggle, size: 40),
        ),
      ],
    );
  }
}

/// Gently sways [child] about its base (±3°, 3000ms ping-pong) — the Garden
/// button's leaf on the placement intro. Mirrors onboarding_scenery's
/// `_SwayingBloom`; frozen under reduced-motion.
class _SwayingLeaf extends StatefulWidget {
  final Widget child;
  const _SwayingLeaf({required this.child});

  @override
  State<_SwayingLeaf> createState() => _SwayingLeafState();
}

class _SwayingLeafState extends State<_SwayingLeaf>
    with SingleTickerProviderStateMixin {
  static const double _maxRad = 3.0 * math.pi / 180;

  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  late final Animation<double> _angle = Tween<double>(
    begin: -_maxRad,
    end: _maxRad,
  ).animate(CurvedAnimation(parent: _sway, curve: Curves.easeInOut));

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations || _started) return;
    _started = true;
    _sway.repeat(reverse: true);
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _sway,
      builder: (_, child) => Transform.rotate(
        angle: reducedMotion ? 0 : _angle.value,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: widget.child,
    );
  }
}
