// Session Call — the voice-first conversation screen (new garden design). Thin
// wiring over ConversationView: maps the live ChatState → display inputs and
// hands the existing chatProvider methods back as callbacks. All look/feel lives
// in ConversationView; the engine/state machine is unchanged.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_toast.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../core/topic_data.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/audio_service.dart';
import 'widgets/conversation_view.dart';
import 'widgets/garden_sky_background.dart';

const String _kGoodbye = 'It was great talking to you. See you again later!';

class SessionScreen extends ConsumerStatefulWidget {
  final String? introText;
  final VoidCallback? onEnded;

  /// When set (a topic tapped on the home screen), overrides the engine's topic
  /// pick for this session's POST /session; otherwise the engine chooses.
  final Topic? initialTopic;

  const SessionScreen({
    super.key,
    this.introText,
    this.onEnded,
    this.initialTopic,
  });

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _textController = TextEditingController();
  bool _sessionStarted = false;
  bool _keyboardMode = false;
  bool _ending = false;

  // True while a tapped-speaker replay is speaking — drives Zoe's speaking
  // animation for manual replays (engine status only covers auto-speech).
  bool _replaying = false;

  @override
  void dispose() {
    ref.read(chatProvider.notifier).stopListening();
    _textController.dispose();
    super.dispose();
  }

  void _maybeStartSession() {
    if (_sessionStarted) return;
    final s = ref.read(chatProvider);
    if (s.hasValue &&
        !s.requireValue.sessionEnded &&
        s.requireValue.messages.isEmpty) {
      _sessionStarted = true;
      ref
          .read(chatProvider.notifier)
          .startSession(topicOverride: widget.initialTopic);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _onMic(ChatState s) {
    final notifier = ref.read(chatProvider.notifier);
    if (s.status == ChatStatus.userSpeaking) {
      notifier.stopListening();
    } else if (s.status == ChatStatus.idle && !s.sessionEnded) {
      notifier.startListening().catchError(_snack);
    }
  }

  void _toggleKeyboard() => setState(() => _keyboardMode = !_keyboardMode);

  void _sendTyped() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _keyboardMode = false);
    ref.read(chatProvider.notifier).sendUserTurn(text).catchError(_snack);
  }

  /// End-call: no confirm. Fire scoring in the background, speak Zoe's goodbye
  /// line, then return to the garden.
  Future<void> _endConversation() async {
    if (_ending) return;
    setState(() => _ending = true);
    final notifier = ref.read(chatProvider.notifier);
    await notifier.stopListening();
    // Speak the goodbye line before navigating away
    try {
      final tts = ref.read(ttsProvider);
      await tts.speak(_kGoodbye);
    } catch (_) {}
    // Fire scoring in the background (don't wait)
    unawaited(notifier.endChat().catchError(_snack));
    // Brief pause after TTS finishes
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final onEnded = widget.onEnded;
    Navigator.of(context).pop();
    if (onEnded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onEnded());
    }
  }

  void _snack(Object e) {
    if (!mounted) return;
    debugPrint('[Session] $e');
    showEllaErrorToast(context);
  }

  /// Whether a real conversation is under way (at least one non-system turn and
  /// not already finishing) — the case where backing out needs a confirmation.
  bool _hasActiveChat(ChatState s) =>
      !_ending &&
      !s.sessionEnded &&
      s.messages.any((m) => m.sender != MessageSender.system);

  /// Back pressed mid-chat: confirm, then discard the in-progress chat (no
  /// scoring) so any topic picked next starts a fresh session, and leave.
  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: EllaColors.surface,
        title: Text('Leave this chat?', style: EllaTextStyles.titleSmall),
        content: Text(
          "If you go back now, this chat won't be saved.",
          style: EllaTextStyles.bodyBase,
        ),
        actions: [
          TextButton(
            onPressed: () {
              playTapClick();
              Navigator.of(dialogContext).pop(false);
            },
            child: Text(
              'Keep talking',
              style: EllaTextStyles.button.copyWith(color: EllaColors.greenDeep),
            ),
          ),
          TextButton(
            onPressed: () {
              playTapClick();
              Navigator.of(dialogContext).pop(true);
            },
            child: Text(
              'Leave',
              style: EllaTextStyles.button.copyWith(color: EllaColors.berryDark),
            ),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    await ref.read(chatProvider.notifier).abandonSession();
    if (mounted) Navigator.of(context).pop();
  }

  // ── ChatState → display mapping ──────────────────────────────────────────────

  String? _lastFrom(ChatState s, MessageSender who) {
    for (final m in s.messages.reversed) {
      if (m.sender == who) return m.text;
    }
    return null;
  }

  ChatMessage? _lastTurn(ChatState s) {
    for (final m in s.messages.reversed) {
      if (m.sender != MessageSender.system) return m;
    }
    return null;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen(chatProvider, (_, _) => _maybeStartSession());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartSession());

    final chatAsync = ref.watch(chatProvider);
    final s = chatAsync.asData?.value;
    final active = s != null && _hasActiveChat(s);

    return PopScope(
      // Block system/predictive back mid-chat so we can confirm first. The End
      // button and the confirmed-exit path pop imperatively, which is unaffected.
      canPop: !active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: EllaColors.surfaceVariant,
        body: chatAsync.when(
          loading: () => const GardenSkyBackground(
            child: Center(
              child: CircularProgressIndicator(color: EllaColors.berryDark),
            ),
          ),
          error: (e, _) => GardenSkyBackground(
            child: Center(
              child: Text(
                'Error: $e',
                style: const TextStyle(color: EllaColors.ink),
              ),
            ),
          ),
          data: (s) => _view(s),
        ),
      ),
    );
  }

  Widget _view(ChatState s) {
    final hasTurn = s.messages.any((m) => m.sender != MessageSender.system);

    final ConvPhase phase;
    if (_ending) {
      phase = ConvPhase.ending;
    } else if (!hasTurn && !s.sessionEnded) {
      phase = ConvPhase.prepare;
    } else {
      phase = ConvPhase.talking;
    }

    final micState = switch (s.status) {
      ChatStatus.userSpeaking => MicState.listening,
      ChatStatus.zoeThinking || ChatStatus.zoeSpeaking => MicState.busy,
      ChatStatus.idle => MicState.idle,
    };

    // Latest-turn content.
    final zoeLine = _ending
        ? _kGoodbye
        : (_lastFrom(s, MessageSender.zoe) ?? widget.introText);

    String? studentLine;
    bool studentLive = false;
    if (!_ending) {
      if (s.status == ChatStatus.userSpeaking) {
        final p = s.partialStt?.trim() ?? '';
        studentLine = p.isEmpty ? null : p;
        studentLive = true;
      } else {
        // Show student's last message until the user starts speaking next turn.
        // This keeps the bubble visible while Zoe is thinking/speaking.
        final lastChild = s.messages.lastWhere(
          (m) => m.sender == MessageSender.child,
          orElse: () => ChatMessage(sender: MessageSender.system, text: ''),
        );
        if (lastChild.sender == MessageSender.child) {
          studentLine = lastChild.text;
        }
      }
    }

    return ConversationView(
      phase: phase,
      mascotSpeaking:
          _ending || s.status == ChatStatus.zoeSpeaking || _replaying,
      mascotThinking: s.status == ChatStatus.zoeThinking,
      zoeLine: zoeLine,
      studentLine: studentLine,
      studentLive: studentLive,
      micState: micState,
      textMode: _keyboardMode,
      textController: _textController,
      onMic: () => _onMic(s),
      onToggleKeyboard: _toggleKeyboard,
      onSend: _sendTyped,
      onEnd: _endConversation,
      // Speaker dot on Zoe's bubble: replays the line when idle. While she's
      // already talking the tap is a no-op (never stops or restarts her). Only
      // Zoe's lines get the control — the student bubble has none.
      onSpeakAgain: (zoeLine != null && zoeLine.trim().isNotEmpty)
          ? () => _speakLine(zoeLine)
          : null,
      highlightStart: s.highlightStart,
      highlightEnd: s.highlightEnd,
    );
  }

  /// Replays a Zoe line via TTS — the speaker dot on her bubble. A no-op while
  /// TTS is already speaking, so a tap can never restart or stack utterances.
  /// Sets [_replaying] around the playback so Zoe animates her mouth for the
  /// manual replay too (not just engine-driven speech).
  Future<void> _speakLine(String text) async {
    final tts = ref.read(ttsProvider);
    if (tts.isSpeaking || _replaying) return;
    setState(() => _replaying = true);
    try {
      await tts.speak(text);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _replaying = false);
    }
  }
}
