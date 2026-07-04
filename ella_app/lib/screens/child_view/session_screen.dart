// Session Call — the voice-first conversation screen (new garden design). Thin
// wiring over ConversationView: maps the live ChatState → display inputs and
// hands the existing chatProvider methods back as callbacks. All look/feel lives
// in ConversationView; the engine/state machine is unchanged.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_colors.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import 'widgets/conversation_view.dart';
import 'widgets/garden_sky_background.dart';

const String _kGoodbye = 'It was great talking to you. See you again later!';

class SessionScreen extends ConsumerStatefulWidget {
  final String? introText;
  final VoidCallback? onEnded;

  const SessionScreen({super.key, this.introText, this.onEnded});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _textController = TextEditingController();
  bool _sessionStarted = false;
  bool _keyboardMode = false;
  bool _ending = false;

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
      ref.read(chatProvider.notifier).startSession();
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

  /// End-call: no confirm. Fire scoring in the background, show Zoe's goodbye
  /// line for a beat, then return to the garden.
  Future<void> _endConversation() async {
    if (_ending) return;
    setState(() => _ending = true);
    final notifier = ref.read(chatProvider.notifier);
    unawaited(notifier.stopSpeaking());
    unawaited(notifier.stopListening());
    unawaited(notifier.endChat().catchError(_snack));
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onEnded?.call();
  }

  void _snack(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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

    return Scaffold(
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
        final last = _lastTurn(s);
        if (last != null && last.sender == MessageSender.child) {
          studentLine = last.text;
        }
      }
    }

    return ConversationView(
      phase: phase,
      mascotSpeaking: _ending || s.status == ChatStatus.zoeSpeaking,
      mascotThinking: s.status == ChatStatus.zoeThinking,
      zoeLine: zoeLine,
      studentLine: studentLine,
      studentLive: studentLive,
      zoeIsReading: s.status == ChatStatus.zoeSpeaking,
      micState: micState,
      textMode: _keyboardMode,
      textController: _textController,
      onMic: () => _onMic(s),
      onToggleKeyboard: _toggleKeyboard,
      onSend: _sendTyped,
      onEnd: _endConversation,
    );
  }
}
