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
import 'package:dotted_border/dotted_border.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../services/audio_service.dart';
import '../chat_bubble.dart';
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
    this.highlightStart = -1,
    this.highlightEnd = -1,
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
              // Mascot stays fixed at the top — only the bubbles below it
              // scroll.
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
              // Latest-turn bubbles live in a scroll region so a long turn can't
              // overflow the screen (or get clipped when the keyboard is up).
              // `reverse: true` pins the newest bubble just above the dock and
              // lets the older text scroll up and disappear under the fixed
              // mascot; the minHeight box keeps short turns top-aligned (right
              // under the mascot) exactly as before.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    reverse: true,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
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
        if (zoeLine != null)
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _ZoeBubble(
                text: zoeLine!,
                onSpeakAgain: onSpeakAgain,
                speaking: speaking,
                highlightStart: highlightStart,
                highlightEnd: highlightEnd,
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
  final int highlightStart;
  final int highlightEnd;

  const _ZoeBubble({
    required this.text,
    required this.onSpeakAgain,
    this.speaking = false,
    this.highlightStart = -1,
    this.highlightEnd = -1,
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
      child: TypewriterText(
        text: text,
        style: EllaTextStyles.bodySemibold,
        highlightStart: highlightStart,
        highlightEnd: highlightEnd,
        animate: false,
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFCE4EC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: SpokenTextFlow(
          text: text,
          style: EllaTextStyles.bodySemibold.copyWith(
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
