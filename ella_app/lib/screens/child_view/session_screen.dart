// Session Call — the voice-first conversation screen (new garden design). Thin
// wiring over ConversationView: maps the live ChatState → display inputs and
// hands the existing chatProvider methods back as callbacks. All look/feel lives
// in ConversationView; the engine/state machine is unchanged.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/offline_alert_popup.dart';
import '../../core/theme_colors.dart';
import '../../core/topic_data.dart';
import '../../models/child_memory.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/stt_tts_service.dart';
import 'widgets/conversation_view.dart';
import 'widgets/mascot_loading_screen.dart';
import 'widgets/need_to_go_sheet.dart';
import 'widgets/network_error_view.dart';

const String _kGoodbye = 'Great talking with you. See you next time!';

class SessionScreen extends ConsumerStatefulWidget {
  final String? introText;
  final VoidCallback? onEnded;

  /// When set (a topic tapped on the home screen), overrides the engine's topic
  /// pick for this session's POST /session; otherwise the engine chooses.
  final Topic? initialTopic;

  /// Home-screen presentation metadata. Kept separate from [initialTopic] so
  /// icon and short-label concerns do not leak into the conversation engine.
  final TopicChoice? topicPresentation;

  const SessionScreen({
    super.key,
    this.introText,
    this.onEnded,
    this.initialTopic,
    this.topicPresentation,
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

  // Back-button "Need to go?" sheet: while it's up Zoe rests (paused/sway) and
  // her in-flight speech is stopped. [_sheetOpen] guards the second back press
  // (double-back → leave). [_interruptedZoeLine] is the line to resume on
  // "Keep talking" if she was mid-speech when the sheet opened.
  bool _paused = false;
  bool _sheetOpen = false;
  String? _interruptedZoeLine;

  // True while a tapped-speaker replay is speaking — drives Zoe's speaking
  // Replay
  bool _replaying = false;

  int _highlightStart = -1;
  int _highlightEnd = -1;
  bool _speaking = false;
  StreamSubscription? _ttsProgressSub;
  StreamSubscription? _ttsDoneSub;

  // Captured in initState so dispose() never reads `ref` (unreliable while the
  // element is deactivating) — otherwise the stop-on-leave can silently fail.
  late final TtsInterface _tts;
  late final ChatNotifier _chatNotifier;

  @override
  void initState() {
    super.initState();
    // Keep the display awake for the whole voice session — the child talks and
    // listens without touching the screen, so the OS idle timer would otherwise
    // dim and lock it mid-conversation. Released in dispose().
    WakelockPlus.enable();
    AnalyticsService.logScreenView('Chat');
    final topicName = widget.initialTopic?.topic ?? 'Free Talk';
    AnalyticsService.logConversationStarted(topicName);
    _tts = ref.read(ttsProvider);
    _chatNotifier = ref.read(chatProvider.notifier);
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
    // Speak the starter message once this screen is mounted.
    // startSession sets state to zoeSpeaking but skips tts.speak() so that
    // audio never fires before the screen appears. We own it here instead.
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakStarterIfReady());
  }

  Future<void> _speakStarterIfReady() async {
    if (!mounted) return;

    // Wait for chatProvider to populate the starter message. On clean launches,
    // startSession() calls the async API to create the conversation, which takes
    // a brief moment to complete.
    ChatState? s;
    for (var i = 0; i < 50; i++) {
      s = ref.read(chatProvider).valueOrNull;
      if (s != null &&
          s.status == ChatStatus.zoeSpeaking &&
          s.messages.length == 1 &&
          s.messages.first.sender == MessageSender.zoe) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    if (s == null) return;

    if (s.status == ChatStatus.zoeSpeaking &&
        s.messages.length == 1 &&
        s.messages.first.sender == MessageSender.zoe) {
      final text = s.messages.first.text;
      try {
        // chatProvider.build() already called tts.initialize() — don't call
        // it again here to avoid race conditions on first launch.
        await _tts.speak(text);
      } catch (_) {}
      if (mounted) {
        ref.read(chatProvider.notifier).markStarterSpoken();
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
    try {
      _chatNotifier.stopListening();
      _tts.stop();
    } catch (_) {}
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

  void _navigateOut() {
    _navigated = true;
    final onEnded = widget.onEnded;
    if (onEnded != null) {
      final route = ModalRoute.of(context);
      if (route != null) {
        Navigator.of(context).removeRoute(route);
      }
      // Call onEnded after the route is removed so the home screen context
      // is active and can push the garden route without a null context crash.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onEnded();
      });
      return;
    }
    Navigator.of(context).pop();
  }

  void _maybeAdvance(ChatState s) {
    // A manual End Call owns its complete farewell -> pause -> garden sequence.
    // The judge can resolve almost immediately for a short conversation, so
    // reacting to sessionEnded here would otherwise pop the route while the
    // fixed goodbye is still being spoken.
    if (_ending || !s.sessionEnded || _navigated) return;
    if (s.currentlySpeakingMessageId != null) {
      if (!_advanceTimerStarted) {
        _advanceTimerStarted = true;
        // Safety net: force navigation back to garden after 5 seconds even if TTS completion handler fails to fire
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_navigated && !_ending) {
            _navigateOut();
          }
        });
      }
      return;
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _navigateOut();
      }
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _onMic(ChatState s) {
    final notifier = ref.read(chatProvider.notifier);
    if (s.status == ChatStatus.userSpeaking) {
      notifier.stopListening();
    } else if (s.status == ChatStatus.zoeSpeaking && !s.sessionEnded) {
      // Interrupt Zoe — stop her speech, then start listening
      _tts.stop();
      notifier.markStarterSpoken(); // reset status to idle
      notifier.startListening().catchError(_snack);
    } else if (s.status == ChatStatus.idle && !s.sessionEnded) {
      notifier.startListening().catchError(_snack);
    }
  }

  void _toggleKeyboard() {
    setState(() => _keyboardMode = !_keyboardMode);
    AnalyticsService.logKeyboardToggled(_keyboardMode);
  }

  void _sendTyped() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _keyboardMode = false);
    AnalyticsService.logKeyboardToggled(false);
    ref.read(chatProvider.notifier).sendUserTurn(text).catchError(_snack);
  }

  /// End-call: no confirm. Fire scoring in the background, speak Zoe's goodbye
  /// line, then return to the garden.
  Future<void> _endConversation() async {
    if (_ending) return;
    setState(() {
      _ending = true;
      _paused = false;
      _sheetOpen = false;
      _speaking = true;
    });

    final chatState = ref.read(chatProvider).valueOrNull;
    if (chatState != null && !chatState.sessionEnded) {
      AnalyticsService.logConversationAbandoned(
        topic: chatState.currentTopic?.topic ?? 'Free Talk',
        turnCount: chatState.turnCount,
      );

      // P0 enriched conversation_ended (manual_end)
      final notifierRef = ref.read(chatProvider.notifier);
      final sessionStart = notifierRef.sessionStartedAt ?? DateTime.now();
      AnalyticsService.logConversationEnded(
        userId: notifierRef.childId,
        sessionId: chatState.activeSessionId ?? '',
        endState: 'manual_end',
        studentTurns: chatState.turnCount,
        startedAt: sessionStart,
        endedAt: DateTime.now(),
      );
    }
    final notifier = ref.read(chatProvider.notifier);
    await notifier.stopListening();

    // Fire scoring in the background (don't wait)
    unawaited(notifier.endChat().catchError(_snack));

    // First stop any current speech explicitly to clear active playback
    final nativeTts = ref.read(nativeTtsProvider);
    await nativeTts.stop();
    // Allow any pending stop callback events to drain from the native channel
    await Future.delayed(const Duration(milliseconds: 150));

    // NativeTtsService.speak completes only when playback finishes (with its
    // own 30-second failure timeout). Do not race it with judge completion or a
    // shorter route timer: the whole farewell must land first.
    try {
      await _tts.speak(_kGoodbye);
    } catch (_) {}
    if (!mounted || _navigated) return;

    // Let the completed line breathe before revealing the garden.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || _navigated) return;

    _navigateOut();
  }

  void _snack(Object e) {
    if (!mounted) return;
    OfflineAlertPopup.show(context);
  }

  /// Whether a real conversation is under way (at least one non-system turn and
  /// not already finishing) — the case where backing out needs a confirmation.
  bool _hasActiveChat(ChatState s) =>
      !_ending &&
      !s.sessionEnded &&
      s.messages.any((m) => m.sender != MessageSender.system);

  /// Back pressed mid-chat: open the "Need to go?" sheet. Zoe rests (paused +
  /// sway) behind a dimmed scrim and any in-flight speech/listening is stopped.
  /// "Keep talking" restores her (resuming an interrupted line); "Bye for now,
  /// Zoe" runs the normal end flow (score → goodbye → garden). Dismissing the
  /// scrim is treated as "keep talking".
  Future<void> _showNeedToGoSheet() async {
    if (_sheetOpen || _ending) return;

    // Pause Zoe: remember the line she was speaking so we can resume it, then
    // stop TTS + STT. (TTS exposes no mid-utterance resume, so we re-speak the
    // whole line on "Keep talking".)
    final s = ref.read(chatProvider).asData?.value;
    _interruptedZoeLine = (_speaking || _replaying) && s != null
        ? _lastFrom(s, MessageSender.zoe)
        : null;
    await ref.read(chatProvider.notifier).stopListening();
    await ref.read(ttsProvider).stop();
    await ref.read(nativeTtsProvider).stop();
    if (!mounted) return;

    setState(() {
      _paused = true;
      _sheetOpen = true;
      _replaying = false;
      _speaking = false;
      _highlightStart = -1;
      _highlightEnd = -1;
    });

    final result = await showNeedToGoSheet(context);
    if (!mounted) return;
    _sheetOpen = false;

    if (result == NeedToGoResult.leave) {
      AnalyticsService.logExitSheetInteraction('leave');
      // The pause sheet is gone; Zoe speaks the farewell before navigation.
      await _endConversation();
      return;
    }

    AnalyticsService.logExitSheetInteraction('keep_talking');

    // Keep talking (or dismissed): resume the conversation.
    final resumeLine = _interruptedZoeLine;
    _interruptedZoeLine = null;
    setState(() => _paused = false);
    if (resumeLine != null && resumeLine.trim().isNotEmpty) {
      _speakLine(resumeLine);
    }
  }

  // ── ChatState → display mapping ──────────────────────────────────────────────

  String? _lastFrom(ChatState s, MessageSender who) {
    for (final m in s.messages.reversed) {
      if (m.sender == who) return m.text;
    }
    return null;
  }

  TopicChoice _topicPresentationFor(ChatState s) {
    final supplied = widget.topicPresentation;
    if (supplied != null) return supplied;
    final name =
        s.currentTopic?.topic ?? widget.initialTopic?.topic ?? 'Free Talk';
    return TopicChoice(name: name, label: name);
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
      canPop: !active && !_ending,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_sheetOpen) {
          // Double-back: dismiss the sheet and run the full leave flow.
          Navigator.of(context).pop(NeedToGoResult.leave);
        } else {
          _showNeedToGoSheet();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: EllaColors.surfaceVariant,
        body: chatAsync.when(
          loading: () =>
              const MascotLoadingScreen(message: 'Starting session...'),
          error: (e, _) =>
              NetworkErrorView(onRetry: () => ref.invalidate(chatProvider)),
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
      ChatStatus.zoeThinking => MicState.busy,
      ChatStatus.zoeSpeaking =>
        MicState.idle, // Allow interrupt — user can tap to cut in
      ChatStatus.idle || ChatStatus.offline => MicState.idle,
    };

    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    // Latest-turn content.
    final zoeLine = _ending
        ? _kGoodbye
        : (_lastFrom(s, MessageSender.zoe) ?? widget.introText);

    // In this voice-first flow, student transcription bubbles are hidden fully at all times.
    const String? studentLine = null;
    const bool studentLive = false;

    final speechLevel = ref.watch(sttLevelProvider);

    return ConversationView(
      phase: phase,
      topic: _topicPresentationFor(s),
      animateTopicHeader: widget.topicPresentation != null,
      mascotPaused: _paused,
      mascotSpeaking:
          _ending ||
          s.status == ChatStatus.zoeSpeaking ||
          _replaying ||
          _speaking,
      mascotThinking: s.status == ChatStatus.zoeThinking,
      isOffline: !isOnline,
      zoeLine: zoeLine,
      studentLine: studentLine,
      studentLive: studentLive,
      speechLevel: speechLevel,
      micState: micState,
      textMode: _keyboardMode,
      textController: _textController,
      onMic: isOnline
          ? () => _onMic(s)
          : () {
              OfflineAlertPopup.show(context);
            },
      onToggleKeyboard: isOnline
          ? _toggleKeyboard
          : () {
              OfflineAlertPopup.show(context);
            },
      onSend: isOnline
          ? _sendTyped
          : () {
              OfflineAlertPopup.show(context);
            },
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

  /// Replays a Zoe line via TTS — the speaker dot on her bubble. While TTS is
  /// already speaking, tapping it stops (mutes) the speech. Sets [_replaying]
  /// around the playback so Zoe animates her mouth for the manual replay too
  /// (not just engine-driven speech).
  Future<void> _speakLine(String text) async {
    final tts = ref.read(ttsProvider);
    if (_speaking || _replaying) {
      await tts.stop();
      if (mounted) {
        setState(() {
          _replaying = false;
          _speaking = false;
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
      return;
    }
    setState(() {
      _replaying = true;
      _speaking = true;
      _highlightStart = -1;
      _highlightEnd = -1;
    });
    AnalyticsService.logReplayClicked(text);
    try {
      await tts.speak(text);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _replaying = false);
    }
  }
}
