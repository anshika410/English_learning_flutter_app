// ConversationView — pure presentation for the voice-first conversation screen
// (Figma "Learning Flow" call frames). No provider/engine imports: it takes
// display inputs + callbacks so each state can be rendered from mock data
// or from live ChatState (see session_screen).
//
// Layout: botanical home-scene backdrop, the sprout mascot pinned near the top, the
// current turn's bubbles (Zoe cream-left, student pink-right), and a bottom dock
// — voice ([keyboard · mic "Tap to Speak" · end-call]) or text (field + send +
// "Switch to Speaking"). Prepare and ending phases replace the middle/dock.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../../core/ella_smooth_shape.dart';
import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../models/child_memory.dart';
import '../../../services/audio_service.dart';
import 'chat_reply_composer.dart';
import 'home_scene_background.dart';
import 'speaker_dot_button.dart';
import 'topic_handoff.dart';
import 'zoe_mascot.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../chat_bubble.dart';

enum ConvPhase { prepare, talking, ending }

enum MicState { idle, listening, busy }

final _dummySpeechLevel = ValueNotifier<double>(0.0);

class ConversationView extends StatelessWidget {
  final ConvPhase phase;
  final TopicChoice? topic;
  final bool animateTopicHeader;
  final bool mascotSpeaking;
  final bool mascotThinking; // Zoe is preparing her reply
  final bool isOffline;

  /// Zoe is "paused" behind the back-button sheet — eyes closed, gentle sway.
  /// Takes precedence over speaking/thinking/listening so she rests while the
  /// sheet is up.
  final bool mascotPaused;

  /// Latest-turn content. Zoe's line is always shown while talking/ending; the
  /// student bubble only appears for the current turn.
  final String? zoeLine;
  final String? studentLine;
  final bool studentLive; // student is mid-speech (live partial)

  final MicState micState;
  final bool textMode;
  final TextEditingController? textController;
  final ValueNotifier<double>? speechLevel;

  final VoidCallback? onMic;
  final VoidCallback? onToggleKeyboard;
  final VoidCallback? onSend;
  final VoidCallback? onEnd;

  /// Toggles TTS for Zoe's current line — powers the speaker dot straddling
  /// her bubble's top-right border (shown for every Zoe line, including the
  /// goodbye). Callers replay when idle and stop while she's speaking. The
  /// student bubble has no such control (by design — only Zoe's lines replay).
  final VoidCallback? onSpeakAgain;

  /// Placement progress in 0..1 (Figma "Placement Flow" top bar). Null hides
  /// the bar entirely — the normal chat (SessionScreen) has no fixed turn
  /// target, so it passes null.
  final double? progress;
  final int highlightStart;
  final int highlightEnd;

  const ConversationView({
    super.key,
    required this.phase,
    this.topic,
    this.animateTopicHeader = false,
    required this.mascotSpeaking,
    this.mascotThinking = false,
    this.isOffline = false,
    this.mascotPaused = false,
    this.zoeLine,
    this.studentLine,
    this.studentLive = false,
    this.micState = MicState.idle,
    this.textMode = false,
    this.textController,
    this.speechLevel,
    this.onMic,
    this.onToggleKeyboard,
    this.onSend,
    this.onEnd,
    this.onSpeakAgain,
    this.progress,
    this.highlightStart = -1,
    this.highlightEnd = -1,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // Figma: 150.55 x 180, sitting a touch below the top.
    final mascotSize = (w * 0.35).clamp(140.0, 158.0);
    final bubbleMaxWidth = w * 0.86;

    final mascot = ZoeMascot(
      key: const ValueKey('conversation-zoe-mascot'),
      mode: isOffline
          ? ZoeMascotMode.sleep
          : phase == ConvPhase.ending && mascotSpeaking
          ? ZoeMascotMode.speaking
          : mascotPaused
          ? ZoeMascotMode.paused
          : mascotSpeaking
          ? ZoeMascotMode.speaking
          : mascotThinking
          ? ZoeMascotMode.thinking
          : ZoeMascotMode.listening,
      size: mascotSize,
      reducedMotion: MediaQuery.of(context).disableAnimations,
    );

    final content = SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Padding(
                key: ValueKey(
                  phase == ConvPhase.prepare
                      ? 'conversation-prepare-content'
                      : 'conversation-active-content',
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Placement progress bar (Figma "Placement Flow"): a thin rounded
                    // track pinned at the very top that fills as the screening
                    // advances. Null on the normal chat (no fixed turn count).
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      _ProgressBar(value: progress!),
                      const SizedBox(height: 12),
                    ] else
                      SizedBox(
                        height: topic == null
                            ? 28
                            : phase == ConvPhase.prepare
                            ? 60
                            : 76,
                      ),
                    // During prepare phase, mascot and card are centered together.
                    // Otherwise, mascot stays fixed at the top.
                    if (phase != ConvPhase.prepare) ...[
                      mascot,
                      SizedBox(height: topic == null ? 18 : 16),
                    ],
                    // Latest-turn bubbles live in a scroll region so a long turn can't
                    // overflow the screen (or get clipped when the keyboard is up).
                    // `reverse: true` pins the newest bubble just above the dock and
                    // lets the older text scroll up and disappear under the fixed
                    // mascot; the minHeight box keeps short turns top-aligned (right
                    // under the mascot) exactly as before. In the prepare phase the
                    // mascot + card centre in the space instead (Figma loader frame).
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              reverse: true,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: phase == ConvPhase.prepare
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.start,
                                  children: [
                                    if (phase == ConvPhase.prepare) ...[
                                      mascot,
                                      const SizedBox(height: 18),
                                      const _PrepareCard(),
                                    ] else
                                      _Bubbles(
                                        zoeLine: zoeLine,
                                        studentLine: studentLine,
                                        onSpeakAgain: onSpeakAgain,
                                        speaking: mascotSpeaking,
                                        maxWidth: bubbleMaxWidth,
                                        highlightStart: highlightStart,
                                        highlightEnd: highlightEnd,
                                      ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                      ),
                    ),
                    if (phase == ConvPhase.talking) ...[
                      _FeedbackContainer(
                        micState: micState,
                        speechLevel: speechLevel ?? _dummySpeechLevel,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (phase == ConvPhase.talking)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: textMode
                            ? _TextDock(
                                controller: textController,
                                onSend: onSend,
                                onSwitchToSpeaking: onToggleKeyboard,
                              )
                            : _VoiceDock(
                                micState: micState,
                                mascotThinking: mascotThinking,
                                onMic: onMic,
                                onKeyboard: onToggleKeyboard,
                                onEnd: onEnd,
                              ),
                      )
                    else
                      const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          if (topic != null)
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: ConversationTopicHeader(
                key: ValueKey(topicHandoffHeroTag(topic!)),
                topic: topic!,
                animateEntrance: animateTopicHeader,
              ),
            ),
        ],
      ),
    );

    return HomeSceneBackground(child: content);
  }
}

// ── Progress bar (placement screening) ───────────────────────────────────────

/// Thin rounded top bar (Figma "Placement Flow"): a pale track with a green
/// fill that eases toward [value] (0..1). A small min-fill keeps a sliver
/// visible once the first turn lands (matches the Figma "listening" frame).
class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final full = constraints.maxWidth;
          // Show at least a rounded sliver once any progress exists.
          final width = v <= 0 ? 0.0 : (v * full).clamp(12.0, full);
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: EllaColors.greenLight,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                width: width,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [EllaColors.greenMain, EllaColors.greenDeep],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Bubbles (latest turn only) ───────────────────────────────────────────────

class _Bubbles extends StatelessWidget {
  final String? zoeLine;
  final String? studentLine;
  final VoidCallback? onSpeakAgain;
  final bool speaking;
  final double maxWidth;
  final int highlightStart;
  final int highlightEnd;

  const _Bubbles({
    required this.zoeLine,
    required this.studentLine,
    required this.onSpeakAgain,
    required this.speaking,
    required this.maxWidth,
    this.highlightStart = -1,
    this.highlightEnd = -1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // New Zoe turns cross-fade instead of snapping: the switcher is keyed by
        // the line text, so a changed line fades the old bubble out and the new
        // one in (~250ms). An empty box for null keeps the layout stable.
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: zoeLine == null
                  ? const SizedBox(key: ValueKey('zoe-empty'), width: 1)
                  : _ZoeBubble(
                      key: ValueKey(zoeLine),
                      text: zoeLine!,
                      onSpeakAgain: onSpeakAgain,
                      speaking: speaking,
                      highlightStart: highlightStart,
                      highlightEnd: highlightEnd,
                    ),
            ),
          ),
        ),
        if (studentLine != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _StudentBubble(text: studentLine!),
            ),
          ),
        ],
      ],
    );
  }
}

class _ZoeBubble extends StatelessWidget {
  final String text;
  final int highlightStart;
  final int highlightEnd;

  /// Toggles TTS for this line. When set, a speaker dot straddles the bubble's
  /// top-right border (Figma placement flow): replay when idle, stop while
  /// [speaking].
  final VoidCallback? onSpeakAgain;
  final bool speaking;

  const _ZoeBubble({
    super.key,
    required this.text,
    required this.onSpeakAgain,
    this.speaking = false,
    this.highlightStart = -1,
    this.highlightEnd = -1,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      key: const ValueKey('conversation-zoe-bubble'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        // Squared top-left "tail" pointing at Zoe; blue info border (#5898E0).
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        side: const BorderSide(color: EllaColors.info, width: 2.5),
      ),
      child: TypewriterText(
        text: text,
        style: EllaTextStyles.bodySemiboldLarge,
        highlightStart: highlightStart,
        highlightEnd: highlightEnd,
      ),
    );

    if (onSpeakAgain == null) return bubble;

    // The 40px dot straddles the bubble's top-right corner (Figma "Placement
    // Flow"): it hangs above and off the right edge. Top padding + the negative
    // right offset keep it overhanging while still inside the Stack's hit-test
    // bounds (hit tests outside a Stack's rect are dropped).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 20), child: bubble),
        Positioned(
          top: 0,
          right: -6,
          child: SpeakerDotButton(
            active: speaking,
            onTap: onSpeakAgain,
            size: 40,
          ),
        ),
      ],
    );
  }
}

class _StudentBubble extends StatelessWidget {
  final String text;
  const _StudentBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      color: const Color(0xFFE91E63),
      strokeWidth: 2.5,
      dashPattern: const [8, 4],
      borderType: BorderType.RRect,
      radius: const Radius.circular(18),
      padding: const EdgeInsets.all(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _studentFill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SpokenTextFlow(
          text: text,
          style: EllaTextStyles.bodySemiboldLarge.copyWith(
            color: const Color(0xFF880E4F),
          ),
        ),
      ),
    );
  }
}

// Student bubble fill from speaking.svg (paler than berryLight).
const Color _studentFill = Color(0xFFFFF2F7);

// ── Prepare card ─────────────────────────────────────────────────────────────

// The loader glyph: turns a half-circle clockwise, rests, turns again — for as
// long as the prepare phase (and so this card) is on screen. The sequence spans
// a full turn so `repeat()` wraps back to 0 with no visible seam.
class _RotatingHourglass extends StatefulWidget {
  const _RotatingHourglass();

  @override
  State<_RotatingHourglass> createState() => _RotatingHourglassState();
}

class _RotatingHourglassState extends State<_RotatingHourglass>
    with SingleTickerProviderStateMixin {
  static const _icon = Icon(
    Icons.hourglass_bottom_rounded,
    size: 28,
    color: EllaColors.ink,
  );

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  // Half turn (~600ms), hold (~600ms), half turn, hold.
  late final Animation<double> _angle = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: math.pi,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 25,
    ),
    TweenSequenceItem(tween: ConstantTween(math.pi), weight: 25),
    TweenSequenceItem(
      tween: Tween(
        begin: math.pi,
        end: 2 * math.pi,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 25,
    ),
    TweenSequenceItem(tween: ConstantTween(2 * math.pi), weight: 25),
  ]).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (reducedMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return _icon;
    return AnimatedBuilder(
      animation: _angle,
      builder: (context, child) =>
          Transform.rotate(angle: _angle.value, child: child),
      child: _icon,
    );
  }
}

class _PrepareCard extends StatelessWidget {
  const _PrepareCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('conversation-prepare-card'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: EllaColors.info, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RotatingHourglass(),
          const SizedBox(height: 12),
          Text(
            'Getting ready…',
            textAlign: TextAlign.center,
            style: EllaTextStyles.bodySemiboldLarge.copyWith(
              color: EllaColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Voice dock ([keyboard · mic · end-call]) ─────────────────────────────────

class _VoiceDock extends StatelessWidget {
  final MicState micState;
  final bool mascotThinking;
  final VoidCallback? onMic;
  final VoidCallback? onKeyboard;
  final VoidCallback? onEnd;

  const _VoiceDock({
    required this.micState,
    required this.mascotThinking,
    required this.onMic,
    required this.onKeyboard,
    required this.onEnd,
  });

  static const double _micSize = 100;
  static const double _sideSize = 58;

  @override
  Widget build(BuildContext context) {
    final label = switch (micState) {
      MicState.listening => 'Listening…',
      MicState.busy => mascotThinking ? 'Sending…' : 'Zoe is speaking…',
      MicState.idle => 'Tap to Speak',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: _micSize + 30, // room for the mic + its label below
        child: Stack(
          children: [
            // Keyboard, lower-left; end-call, lower-right — both sit below the mic.
            Positioned(
              left: 0,
              bottom: 8,
              child: _DockCircle(
                glyph: const Icon(
                  Icons.keyboard_alt_outlined,
                  size: 24,
                  color: EllaColors.greenDark,
                ),
                fill: EllaColors.greenLight,
                ring: EllaColors.greenDeep,
                shadow: EllaColors.greenDeep,
                size: _sideSize,
                onTap: onKeyboard,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 8,
              child: _DockCircle(
                key: const ValueKey('conversation-end-call'),
                glyph: const Icon(
                  Icons.call_end_rounded,
                  size: 24,
                  color: EllaColors.error,
                ),
                fill: EllaColors.errorLight,
                ring: EllaColors.errorDark,
                shadow: EllaColors.errorDark,
                size: _sideSize,
                onTap: onEnd,
              ),
            ),
            // Mic + label, raised and centred.
            Align(
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MicButton(state: micState, size: _micSize, onTap: onMic),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: EllaTextStyles.caption.copyWith(
                      color: EllaColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small round dock button. [glyph] is a Widget so Material icons swap cleanly
/// for exported Figma SVGs later.
class _DockCircle extends StatelessWidget {
  final Widget glyph;
  final Color fill;
  final Color ring;
  final Color shadow;
  final double size;
  final VoidCallback? onTap;

  const _DockCircle({
    super.key,
    required this.glyph,
    required this.fill,
    required this.ring,
    required this.shadow,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 2),
          boxShadow: [
            BoxShadow(color: shadow, offset: const Offset(0, 3), blurRadius: 0),
          ],
        ),
        child: glyph,
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final MicState state;
  final double size;
  final VoidCallback? onTap;

  const _MicButton({
    required this.state,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final busy = state == MicState.busy;
    final listening = state == MicState.listening;
    final fill = busy
        ? EllaColors.textDisabled
        : listening
        ? EllaColors.berryDark
        : EllaColors.berryMain;
    final edge = busy ? EllaColors.textTertiary : EllaColors.berryDeep;

    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: edge, width: 3),
          boxShadow: busy
              ? const []
              : const [
                  BoxShadow(
                    color: EllaColors.berryDeep,
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Center(
          child: listening
              ? SvgPicture.asset(
                  'assets/send-button.svg',
                  width: size * 0.44,
                  height: size * 0.44,
                  colorFilter: const ColorFilter.mode(
                    EllaColors.onPrimary,
                    BlendMode.srcIn,
                  ),
                )
              : Icon(
                  Icons.mic_rounded,
                  size: size * 0.44,
                  color: EllaColors.onPrimary,
                ),
        ),
      ),
    );
  }
}

// ── Text dock (field + send + "Switch to Speaking") ──────────────────────────

class _TextDock extends StatelessWidget {
  final TextEditingController? controller;
  final VoidCallback? onSend;
  final VoidCallback? onSwitchToSpeaking;

  const _TextDock({
    required this.controller,
    required this.onSend,
    required this.onSwitchToSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shared reply composer (Figma node 441:26724) — the same field + berry
        // paper-plane send button used across placement, conversation and the
        // name/age onboarding step.
        ChatReplyComposer(
          controller: controller,
          autofocus: true,
          onSend: onSend,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: withTapClick(onSwitchToSpeaking),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mic_rounded,
                size: 22,
                color: EllaColors.greenDeep,
              ),
              const SizedBox(width: 4),
              Text(
                'Switch to Speaking',
                style: EllaTextStyles.bodySemiboldLarge.copyWith(
                  color: EllaColors.greenDeep,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeedbackContainer extends StatelessWidget {
  final MicState micState;
  final ValueNotifier<double> speechLevel;

  const _FeedbackContainer({
    required this.micState,
    required this.speechLevel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: micState == MicState.listening
          ? _ListeningWave(key: const ValueKey('listening-wave'), levelNotifier: speechLevel)
          : const SizedBox(
              key: ValueKey('turn-feedback-empty'),
              height: 48,
            ),
    );
  }
}

class _ListeningWave extends StatefulWidget {
  const _ListeningWave({
    super.key,
    required this.levelNotifier,
  });
  final ValueNotifier<double> levelNotifier;

  static const _colors = [
    Color(0xffe4457c),
    Color(0xffa86fd4),
    Color(0xff5f9de8),
    Color(0xffffc93d),
    Color(0xff59a84c),
    Color(0xffff8a5b),
    Color(0xffe4457c),
  ];

  @override
  State<_ListeningWave> createState() => _ListeningWaveState();
}

class _ListeningWaveState extends State<_ListeningWave> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, widget.levelNotifier]),
      builder: (context, _) {
        final level = widget.levelNotifier.value;
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x66a86fd4), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffe4457c).withValues(alpha: 0.08 + level * 0.18),
                blurRadius: 8 + level * 12,
                spreadRadius: level * 3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(7, (i) {
              final idleWave = (math.sin(_controller.value * math.pi * 2 + i * 0.85) + 1) / 2;
              final centerBoost = 1 - ((i - 3).abs() / 5);
              final height = 8 + idleWave * 6 + level * (15 + centerBoost * 16);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                width: 5,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _ListeningWave._colors[i],
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
