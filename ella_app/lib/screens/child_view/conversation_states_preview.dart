// DEBUG ONLY — renders ConversationView in each Figma "Learning Flow" state from
// canned data, so every state can be eyeballed / screenshotted without driving a
// live conversation. Reachable behind kShowGlassBox (see app.dart). Delete once
// the conversation redesign is signed off.

import 'package:flutter/material.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import 'widgets/conversation_view.dart';

class _PreviewState {
  final String label;
  final ConversationView Function(TextEditingController tc) build;
  const _PreviewState(this.label, this.build);
}

const String _zoe1 =
    "Hi Maya! It's so good to hear your voice. What did you get up to this weekend?";
const String _zoe2 = 'Nice! What did you see in the park?';
const String _student = 'I went to the park with my family';
const String _goodbye = 'It was great talking to you. See you again later!';

class ConversationStatesPreview extends StatefulWidget {
  const ConversationStatesPreview({super.key});

  @override
  State<ConversationStatesPreview> createState() =>
      _ConversationStatesPreviewState();
}

class _ConversationStatesPreviewState extends State<ConversationStatesPreview> {
  final _tc = TextEditingController(text: 'I saw a big dog!');
  int _i = 0;

  late final List<_PreviewState> _states = [
    _PreviewState(
      'Prepare Conversation',
      (_) => const ConversationView(
        phase: ConvPhase.prepare,
        mascotSpeaking: false,
      ),
    ),
    _PreviewState(
      "Zoe's first turn (Speaking)",
      (_) => const ConversationView(
        phase: ConvPhase.talking,
        mascotSpeaking: true,
        zoeLine: _zoe1,
        micState: MicState.busy,
      ),
    ),
    _PreviewState(
      "Zoe's Listening",
      (_) => const ConversationView(
        phase: ConvPhase.talking,
        mascotSpeaking: false,
        zoeLine: _zoe1,
        micState: MicState.idle,
      ),
    ),
    _PreviewState(
      'Student Speaking',
      (_) => const ConversationView(
        phase: ConvPhase.talking,
        mascotSpeaking: false,
        zoeLine: _zoe1,
        studentLine: _student,
        studentLive: true,
        micState: MicState.listening,
      ),
    ),
    _PreviewState(
      "Zoe's Second Turn",
      (_) => const ConversationView(
        phase: ConvPhase.talking,
        mascotSpeaking: true,
        zoeLine: _zoe2,
        micState: MicState.busy,
      ),
    ),
    _PreviewState(
      'Student Typing',
      (tc) => ConversationView(
        phase: ConvPhase.talking,
        mascotSpeaking: false,
        zoeLine: _zoe2,
        textMode: true,
        textController: tc,
      ),
    ),
    _PreviewState(
      'Conversation End',
      (_) => const ConversationView(
        phase: ConvPhase.ending,
        mascotSpeaking: true,
        zoeLine: _goodbye,
      ),
    ),
  ];

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _step(int delta) =>
      setState(() => _i = (_i + delta) % _states.length);

  @override
  Widget build(BuildContext context) {
    final state = _states[_i];
    return Scaffold(
      backgroundColor: EllaColors.surfaceVariant,
      body: Stack(
        children: [
          Positioned.fill(child: state.build(_tc)),
          // Compact stepper overlay, top-centre.
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: () => _step(-1),
                    ),
                    Text(
                      '${_i + 1}/${_states.length}  ${state.label}',
                      style: EllaTextStyles.caption.copyWith(color: Colors.white),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                      onPressed: () => _step(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
