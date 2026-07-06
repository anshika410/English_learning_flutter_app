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

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../services/audio_service.dart';
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
  /// goodbye). Callers replay when idle and stop while she's speaking.
  final VoidCallback? onSpeakAgain;

  /// Replays the student's line via TTS — the speaker dot on the student
  /// bubble (mirrors [onSpeakAgain]; placement-flow behavior). Callers pass
  /// null while the line is still a live partial.
  final VoidCallback? onSpeakStudent;

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
    this.onSpeakStudent,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // Figma: 150.55 x 180, sitting a touch below the top.
    final mascotSize = (w * 0.35).clamp(140.0, 158.0);
    final bubbleMaxWidth = w * 0.78;

    return GardenSkyBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 28),
              ZoeMascot(
                mode: mascotSpeaking
                    ? ZoeMascotMode.speaking
                    : mascotThinking
                        ? ZoeMascotMode.thinking
                        : ZoeMascotMode.listening,
                size: mascotSize,
                reducedMotion: MediaQuery.of(context).disableAnimations,
              ),
              const SizedBox(height: 18),
              if (phase == ConvPhase.prepare)
                const _PrepareCard()
              else
                _Bubbles(
                  zoeLine: zoeLine,
                  studentLine: studentLine,
                  onSpeakAgain: onSpeakAgain,
                  onSpeakStudent: onSpeakStudent,
                  speaking: mascotSpeaking,
                  maxWidth: bubbleMaxWidth,
                ),
              const Spacer(),
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

// ── Bubbles (latest turn only) ───────────────────────────────────────────────

class _Bubbles extends StatelessWidget {
  final String? zoeLine;
  final String? studentLine;
  final VoidCallback? onSpeakAgain;
  final VoidCallback? onSpeakStudent;
  final bool speaking;
  final double maxWidth;

  const _Bubbles({
    required this.zoeLine,
    required this.studentLine,
    required this.onSpeakAgain,
    required this.onSpeakStudent,
    required this.speaking,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (zoeLine != null)
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _ZoeBubble(
                text: zoeLine!,
                onSpeakAgain: onSpeakAgain,
                speaking: speaking,
              ),
            ),
          ),
        if (studentLine != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _StudentBubble(
                text: studentLine!,
                onSpeak: onSpeakStudent,
                speaking: speaking,
              ),
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
    required this.text,
    required this.onSpeakAgain,
    this.speaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: EllaColors.surface,
        // Squared top-left "tail" pointing at Zoe; blue info border (#5898E0).
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: EllaColors.info, width: 2.5),
      ),
      child: Text(text, style: EllaTextStyles.bodySemibold),
    );

    if (onSpeakAgain == null) return bubble;

    // Top padding gives the overhanging dot room inside the Stack's bounds so
    // it stays tappable (hit tests outside a Stack's rect are dropped).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 14), child: bubble),
        Positioned(
          top: 0,
          right: 10,
          child: SpeakerDotButton(active: speaking, onTap: onSpeakAgain),
        ),
      ],
    );
  }
}

class _StudentBubble extends StatelessWidget {
  final String text;

  /// Replays this line via TTS. When set, a speaker dot straddles the bubble's
  /// top-left border (mirroring Zoe's top-right dot): replay when idle, ignore
  /// taps while TTS is [speaking].
  final VoidCallback? onSpeak;
  final bool speaking;

  const _StudentBubble({
    required this.text,
    this.onSpeak,
    this.speaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        // Pale pink (#FFF2F7) with a berryDark border and squared bottom-right
        // tail — matching speaking.svg.
        color: _studentFill,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: EllaColors.berryDark, width: 2.5),
      ),
      // Same font/weight as every other line (no italic, even while live).
      child: Text(text, style: EllaTextStyles.bodySemibold),
    );

    if (onSpeak == null) return bubble;

    // Same headroom trick as _ZoeBubble so the overhanging dot stays tappable.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 14), child: bubble),
        Positioned(
          top: 0,
          left: 10,
          child: SpeakerDotButton(active: speaking, onTap: onSpeak),
        ),
      ],
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
      decoration: BoxDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EllaColors.border, width: 1.5),
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
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: onSend == null ? null : (_) => onSend!(),
                style: EllaTextStyles.bodyBase,
                decoration: InputDecoration(
                  hintText: 'Type your reply…',
                  hintStyle: EllaTextStyles.bodyBase.copyWith(
                    color: EllaColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: EllaColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: _border(EllaColors.border),
                  enabledBorder: _border(EllaColors.border),
                  focusedBorder: _border(EllaColors.borderStrong),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: withTapClick(onSend),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: EllaColors.berryMain,
                  shape: BoxShape.circle,
                  border: Border.all(color: EllaColors.berryDark, width: 2),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  size: 20,
                  color: EllaColors.onPrimary,
                ),
              ),
            ),
          ],
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
                size: 18,
                color: EllaColors.greenDeep,
              ),
              const SizedBox(width: 6),
              Text(
                'Switch to Speaking',
                style: EllaTextStyles.caption.copyWith(
                  color: EllaColors.greenDeep,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide(color: color, width: 1.5),
  );
}
