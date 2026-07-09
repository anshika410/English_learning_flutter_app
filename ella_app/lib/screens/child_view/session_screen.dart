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
import 'widgets/mascot_loading_screen.dart';
import 'widgets/network_error_view.dart';

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
  bool _navigated = false;
  bool _advanceTimerStarted = false;

  // True while a tapped-speaker replay is speaking — drives Zoe's speaking
  // animation for manual replays (engine status only covers auto-speech).
  bool _replaying = false;

  int _highlightStart = -1;
  int _highlightEnd = -1;
  bool _speaking = false;
  StreamSubscription? _ttsProgressSub;
  StreamSubscription? _ttsDoneSub;

  @override
  void initState() {
    super.initState();
    final nativeTts = ref.read(nativeTtsProvider);
    _ttsProgressSub = nativeTts.progressStream.listen((event) {
      if (mounted) {
        setState(() {
          _speaking = true;
          _highlightStart = event.start;
          _highlightEnd = event.end;
        });
      }
    });
    _ttsDoneSub = nativeTts.doneStream.listen((_) {
      if (mounted) {
        setState(() {
          _speaking = false;
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
    });
  }

  @override
  void dispose() {
    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
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

  void _maybeAdvance(ChatState s) {
    if (!s.sessionEnded || _navigated) return;
    if (s.currentlySpeakingMessageId != null) {
      if (!_advanceTimerStarted) {
        _advanceTimerStarted = true;
        // Safety net: force navigation back to garden after 5 seconds even if TTS completion handler fails to fire
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_navigated) {
            _navigated = true;
            final onEnded = widget.onEnded;
            Navigator.of(context).pop();
            if (onEnded != null) {
              onEnded();
            }
          }
        });
      }
      return;
    }
    _navigated = true;
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        final onEnded = widget.onEnded;
        Navigator.of(context).pop();
        if (onEnded != null) {
          onEnded();
        }
      }
    });
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
    
    // Fire scoring in the background (don't wait)
    unawaited(notifier.endChat().catchError(_snack));

    // First stop any current speech explicitly to clear active playback
    final nativeTts = ref.read(nativeTtsProvider);
    await nativeTts.stop();
    // Allow any pending stop callback events to drain from the native channel
    await Future.delayed(const Duration(milliseconds: 150));

    bool popped = false;
    void doPop() {
      if (popped) return;
      popped = true;
      if (mounted) {
        final onEnded = widget.onEnded;
        Navigator.of(context).pop();
        if (onEnded != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onEnded());
        }
      }
    }

    // Safety net: force navigation after 4.5 seconds if TTS done callback fails
    final safetyTimer = Timer(const Duration(milliseconds: 4500), doPop);

    // Listen for TTS done stream to pop as soon as speech finishes
    StreamSubscription? doneSub;
    doneSub = nativeTts.doneStream.listen((_) {
      safetyTimer.cancel();
      doneSub?.cancel();
      Future.delayed(const Duration(milliseconds: 400), doPop);
    });

    try {
      final tts = ref.read(ttsProvider);
      await tts.speak(_kGoodbye);
    } catch (_) {
      safetyTimer.cancel();
      doneSub.cancel();
      doPop();
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
    ref.listen(chatProvider, (previous, next) {
      _maybeStartSession();
      final nextState = next.asData?.value;
      if (nextState != null) {
        if (nextState.status == ChatStatus.zoeSpeaking) {
          setState(() {
            _speaking = true;
            _highlightStart = -1;
            _highlightEnd = -1;
          });
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartSession());

    final chatAsync = ref.watch(chatProvider);
    final s = chatAsync.asData?.value;
    if (s != null) {
      _maybeAdvance(s);
    }
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
          loading: () => const MascotLoadingScreen(message: 'Starting session...'),
          error: (e, _) => NetworkErrorView(
            onRetry: () => ref.invalidate(chatProvider),
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
        // Show live partial while user is actively speaking.
        final p = s.partialStt?.trim() ?? '';
        studentLine = p.isEmpty ? null : p;
        studentLive = true;
      } else {
        // Show student's last message until the user starts speaking next turn.
        // This keeps the bubble visible while Zoe is thinking/speaking.
        final last = s.messages.isNotEmpty ? s.messages.last : null;
        if (last != null && last.sender == MessageSender.child) {
          studentLine = last.text;
        }
      }
    }

    return ConversationView(
      phase: phase,
      mascotSpeaking:
          _ending || s.status == ChatStatus.zoeSpeaking || _replaying || _speaking,
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
      highlightStart: _highlightStart,
      highlightEnd: _highlightEnd,
    );
  }

  /// Replays a Zoe line via TTS — the speaker dot on her bubble. A no-op while
  /// TTS is already speaking, so a tap can never restart or stack utterances.
  /// Sets [_replaying] around the playback so Zoe animates her mouth for the
  /// manual replay too (not just engine-driven speech).
  Future<void> _speakLine(String text) async {
    final tts = ref.read(ttsProvider);
    if (tts.isSpeaking || _replaying) return;
    setState(() {
      _replaying = true;
      _speaking = true;
      _highlightStart = -1;
      _highlightEnd = -1;
    });
    try {
      await tts.speak(text);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _replaying = false);
    }
  }
}
