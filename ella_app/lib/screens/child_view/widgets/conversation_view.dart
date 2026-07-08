// ConversationView — pure presentation for the voice-first conversation screen
// (Figma "Learning Flow" call frames). No provider/engine imports: it takes
// display inputs + callbacks so each state can be rendered from mock data (see
// conversation_states_preview.dart) or from live ChatState (see session_screen).
//
// Layout: garden sky/hills backdrop, the sprout mascot pinned near the top, the
// current turn's bubbles (Zoe cream-left, student pink-right), and a bottom dock
// — voice ([keyboard · mic "Tap to Speak" · end-call]) or text (field + send +
// "Switch to Speaking"). Prepare and ending phases replace the middle/dock.

import 'package:flutter/material.dart';

import '../../../core/ella_smooth_shape.dart';
import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../services/audio_service.dart';
import 'chat_reply_composer.dart';
import 'garden_sky_background.dart';
import 'speaker_dot_button.dart';
import 'zoe_mascot.dart';

enum ConvPhase { prepare, talking, ending }

enum MicState { idle, listening, busy }

class ConversationView extends StatelessWidget {
  final ConvPhase phase;
  final bool mascotSpeaking;
  final bool mascotThinking; // Zoe is preparing her reply

  /// Latest-turn content. Zoe's line is always shown while talking/ending; the
  /// student bubble only appears for the current turn.
  final String? zoeLine;
  final String? studentLine;
  final bool studentLive; // student is mid-speech (live partial)

  final MicState micState;
  final bool textMode;
  final TextEditingController? textController;

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
    required this.mascotSpeaking,
    this.mascotThinking = false,
    this.zoeLine,
    this.studentLine,
    this.studentLive = false,
    this.micState = MicState.idle,
    this.textMode = false,
    this.textController,
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
    final bubbleMaxWidth = w * 0.78;

    final mascot = ZoeMascot(
      mode: mascotSpeaking
          ? ZoeMascotMode.speaking
          : mascotThinking
          ? ZoeMascotMode.thinking
          : ZoeMascotMode.listening,
      size: mascotSize,
      reducedMotion: MediaQuery.of(context).disableAnimations,
    );

    return GardenSkyBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Placement progress bar (Figma "Placement Flow"): a thin rounded
              // track pinned at the very top that fills as the screening
              // advances. Null on the normal chat (no fixed turn count).
              if (progress != null) ...[
                const SizedBox(height: 8),
                _ProgressBar(value: progress!),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 28),
              // Mascot stays fixed at the top — only the bubbles below it
              // scroll.
              mascot,
              const SizedBox(height: 18),
              // Latest-turn bubbles live in a scroll region so a long turn can't
              // overflow the screen (or get clipped when the keyboard is up).
              // `reverse: true` pins the newest bubble just above the dock and
              // lets the older text scroll up and disappear under the fixed
              // mascot; the minHeight box keeps short turns top-aligned (right
              // under the mascot) exactly as before. In the prepare phase the
              // mascot + card centre in the space instead (Figma loader frame).
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    reverse: true,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: phase == ConvPhase.prepare
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          if (phase == ConvPhase.prepare)
                            const _PrepareCard()
                          else
                            _Bubbles(
                              zoeLine: zoeLine,
                              studentLine: studentLine,
                              onSpeakAgain: onSpeakAgain,
                              speaking: mascotSpeaking,
                              maxWidth: bubbleMaxWidth,
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
    );
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

  const _Bubbles({
    required this.zoeLine,
    required this.studentLine,
    required this.onSpeakAgain,
    required this.speaking,
    required this.maxWidth,
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
          alignment: Alignment.centerLeft,
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
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
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
      child: Text(text, style: EllaTextStyles.bodySemiboldLarge),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: ellaSmoothDecoration(
        // Pale pink (#FFF2F7) with a berryDark border and squared bottom-right
        // tail — matching speaking.svg.
        color: _studentFill,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
        side: const BorderSide(color: EllaColors.berryDark, width: 2.5),
      ),
      // Same font/weight as every other line (no italic, even while live).
      child: Text(text, style: EllaTextStyles.bodySemiboldLarge),
    );
  }
}

// Student bubble fill from speaking.svg (paler than berryLight).
const Color _studentFill = Color(0xFFFFF2F7);

// ── Prepare card ─────────────────────────────────────────────────────────────

class _PrepareCard extends StatelessWidget {
  const _PrepareCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: EllaColors.border, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_bottom_rounded,
            size: 24,
            color: EllaColors.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'Preparing your conversation.\nHang on a moment…',
            textAlign: TextAlign.center,
            style: EllaTextStyles.bodySmall.copyWith(
              height: 1.4,
              color: EllaColors.textSecondary,
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
  final VoidCallback? onMic;
  final VoidCallback? onKeyboard;
  final VoidCallback? onEnd;

  const _VoiceDock({
    required this.micState,
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
      MicState.busy => 'Zoe is talking…',
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
      onTap: busy ? null : withTapClick(onTap),
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
        child: Icon(
          listening ? Icons.stop_rounded : Icons.mic_rounded,
          size: size * 0.44,
          color: EllaColors.onPrimary,
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
              const SizedBox(width: 8),
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
