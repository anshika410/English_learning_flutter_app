// Placement intro — the first-run "Homescreen" (Figma "Placement Flow").
// Shown by RootGate before a student has been levelled: the botanical scene,
// the same Garden/Profile header used on Home, Zoe, a warm "tell me about
// yourself" bubble, and a single CTA that starts the voice placement screening.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/offline_alert_popup.dart';
import '../../core/ella_smooth_shape.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/piper_download_provider.dart';
import '../../providers/placement_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/stt_tts_service.dart';
import 'placement_garden_screen.dart';
import 'placement_screen.dart';
import 'profile_screen.dart';
import 'chat_bubble.dart';
import 'widgets/ella_primary_button.dart';
import 'widgets/home_scene_background.dart';
import 'widgets/home_shortcut_header.dart';
import 'widgets/piper_download_banner.dart';
import 'widgets/zoe_mascot.dart';

const String _kVoiceIcon = 'assets/homescreen/new/UserSound.svg';

const String _kGreeting =
    "Let's find a good place to start. I'll ask a few questions about "
    'things you know and like. There are no wrong answers';

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
    final activeTts = ref.read(ttsProvider);
    _ttsProgressSub = activeTts.progressStream.listen((event) {
      if (mounted) {
        setState(() {
          _highlightStart = event.start;
          _highlightEnd = event.end;
        });
      }
    });
    _ttsDoneSub = activeTts.doneStream.listen((_) {
      if (mounted) {
        setState(() {
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
    });
    // Trigger Piper model download in background if not done yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(piperDownloadProvider.notifier).startIfNeeded();
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
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    return HomeSceneBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              HomeShortcutHeader(
                onOpenGarden: _openGarden,
                onOpenProfile: _openProfile,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        key: const ValueKey('placement-home-upper-content'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The regular Home starts Zoe directly below its
                          // shortcuts. Placement sits 16px lower to give this
                          // simpler screen a little more breathing room.
                          const SizedBox(height: 16),
                          ZoeMascot(
                            key: const ValueKey('placement-home-zoe-mascot'),
                            mode: !isOnline
                                ? ZoeMascotMode.sleep
                                : _speaking
                                ? ZoeMascotMode.speaking
                                : ZoeMascotMode.listening,
                            size: mascotW,
                            reducedMotion: MediaQuery.of(
                              context,
                            ).disableAnimations,
                          ),
                          const SizedBox(height: 10),
                          _GreetingCard(
                            speaking: _speaking,
                            onToggle: _toggleSpeak,
                            highlightStart: _highlightStart,
                            highlightEnd: _highlightEnd,
                            text: _kGreeting,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Piper voice model download progress banner
              const PiperDownloadBanner(),
              EllaPrimaryButton(
                key: const ValueKey('placement-home-talk-cta'),
                label: 'Start Talking',
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
    return Container(
      key: const ValueKey('placement-home-greeting-card'),
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
    );
  }
}
