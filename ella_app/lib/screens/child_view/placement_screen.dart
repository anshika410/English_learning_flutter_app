// Placement conversation — the voice screening turns (Figma "Placement Flow").
// Thin wiring over ConversationView, mirroring SessionScreen but driven by
// placementProvider instead of chatProvider. When the backend signals the test
// is complete (or the child ends the chat), it hands off to the
// PlacementGardenScreen, which resolves into the bloom or sprout branch.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme_colors.dart';
import '../../core/offline_alert_popup.dart';
import '../../models/message.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/placement_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/stt_tts_service.dart';
import 'home_screen.dart' show kHomeChildName;
import 'placement_garden_screen.dart';
import 'widgets/conversation_view.dart';
import 'widgets/home_scene_background.dart';

class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});

  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

// Placeholder turn target for the progress bar: the bar fills proportionally by
// Zoe-question count until the hard placement turn count lands (then this
// becomes that number). Swapping this constant is the only change needed.
const int kPlacementTurnTarget = 12;

class _PlacementScreenState extends ConsumerState<PlacementScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _keyboardMode = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  bool _navigated = false;
  bool _advanceTimerStarted = false;
  bool _scheduledExit = false;

  // True while the End-Call closing line is playing (before we hand off to the
  // placement garden). Drives the ending phase: Zoe speaks a fixed farewell that
  // cross-fades in over the last turn, the dock disappears, then a ~2s hold.
  bool _ending = false;

  // Tracks when placement started (for P0 placement_ended event).
  DateTime? _placementStartedAt;

  // True while a tapped-speaker replay is speaking — drives Zoe's speaking
  // animation for manual replays (the engine status only covers auto-speech).
  bool _replaying = false;

  int _highlightStart = -1;
  int _highlightEnd = -1;
  bool _speaking = false;
  StreamSubscription? _ttsProgressSub;
  StreamSubscription? _ttsDoneSub;

  // Captured in initState so dispose() never reads `ref` (unreliable while the
  // element is deactivating) — otherwise the stop-on-leave can silently fail.
  late final TtsInterface _tts;
  late final PlacementNotifier _placementNotifier;

  @override
  void initState() {
    super.initState();
    // Keep the display awake for the whole placement conversation (voice-first,
    // no touch input) so the OS idle timer can't dim/lock it. Released in
    // dispose().
    WakelockPlus.enable();
    AnalyticsService.logScreenView('Placement');
    _tts = ref.read(ttsProvider);
    _placementNotifier = ref.read(placementProvider.notifier);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _stopAllTts();
      }
    });
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
    WakelockPlus.disable();
    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
    try {
      _placementNotifier.stopListening();
      _tts.stop();
    } catch (_) {}
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _maybeStart() {
    final s = ref.read(placementProvider);
    if (!s.started) {
      _placementStartedAt = DateTime.now();
      final userId = ref.read(chatProvider).valueOrNull?.memory.childId ?? '';
      // P0 enriched placement_started — use a unique attempt id per start
      AnalyticsService.logPlacementStartedP0(
        userId: userId,
        placementAttemptId: '${userId}_${_placementStartedAt!.millisecondsSinceEpoch}',
      );
      ref.read(placementProvider.notifier).start();
    }
  }

  // On completion, let the closing line land for a beat, then swap to the
  // placement garden (replace so back never returns into the finished test).
  void _maybeAdvance(PlacementState s) {
    // While the End-Call farewell is playing, _exit owns the transition — don't
    // let the LLM-completion auto-advance cut it short.
    if (_ending || !s.isComplete || _navigated) return;
    if (!s.isComplete || _navigated) return;
    if (s.currentlySpeakingMessageId != null) {
      if (!_advanceTimerStarted) {
        _advanceTimerStarted = true;
        // Safety net: force navigation after 5 seconds even if TTS completion handler fails to fire
        Future.delayed(const Duration(seconds: 5), _exit);
      }
      return;
    }
    if (!_scheduledExit) {
      _scheduledExit = true;
      Future.delayed(const Duration(milliseconds: 1600), _exit);
    }
  }

  // Swap to the placement garden screen (guarded so it only runs once). Used by
  // the auto-advance and by the End button when the screening is already done —
  // so ending a finished test never falls through to the home underneath.
  void _goToComplete() {
    if (_navigated || !mounted) return;
    _navigated = true;

    // P0 placement_ended (completed)
    final userId = ref.read(chatProvider).valueOrNull?.memory.childId ?? '';
    final s = ref.read(placementProvider);
    final studentTurns =
        s.messages.where((m) => m.sender == MessageSender.child).length;
    final startedAt = _placementStartedAt ?? DateTime.now();
    AnalyticsService.logPlacementEnded(
      userId: userId,
      placementAttemptId: '${userId}_${startedAt.millisecondsSinceEpoch}',
      endState: 'completed',
      studentTurns: studentTurns,
      startedAt: startedAt,
      endedAt: DateTime.now(),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PlacementGardenScreen()),
    );
  }

  void _stopAllTts() {
    _tts.stop();
    ref.read(nativeTtsProvider).stop();
    ref.read(placementProvider.notifier).stopSpeaking();
    if (mounted) {
      setState(() {
        _speaking = false;
        _replaying = false;
        _highlightStart = -1;
        _highlightEnd = -1;
      });
    }
  }

  void _onMic(PlacementState s) {
    final notifier = ref.read(placementProvider.notifier);
    if (s.status == ChatStatus.userSpeaking) {
      notifier.stopListening();
    } else if (s.status == ChatStatus.zoeSpeaking && !s.isComplete) {
      _stopAllTts();
      notifier.startListening().catchError(_snack);
    } else if ((s.status == ChatStatus.idle || s.status == ChatStatus.speechError) && !s.isComplete) {
      if (_replaying || _speaking) {
        _stopAllTts();
      }
      notifier.startListening().catchError(_snack);
    }
  }

  void _toggleKeyboard() {
    setState(() => _keyboardMode = !_keyboardMode);
    _stopAllTts();
  }

  void _sendTyped() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _keyboardMode = false);
    ref.read(placementProvider.notifier).sendUserTurn(text).catchError(_snack);
  }

  // Fixed farewell spoken when the child taps End Call before the screening
  // finishes on its own. Personalised with the onboarding name.
  String _closingLine() {
    final name =
        ref.read(onboardingProvider).valueOrNull?.firstName ?? kHomeChildName;
    return 'Thanks for talking with me, $name. You can continue anytime';
  }

  // End the placement screening (hard end — no farewell turn is posted): the
  // notifier stops voice, marks the test complete and refreshes memory to check
  // whether a level was persisted. Rather than cutting away instantly, we speak
  // a fixed closing line (which cross-fades in over the last turn and drops the
  // dock), hold ~2s, then route to the placement garden — which branches on the
  // resolved level (bloom vs sprout). Repeat taps are absorbed by _ending +
  // the notifier's `ending` guard + _navigated.
  Future<void> _exit() async {
    if (_ending || _navigated) return;

    setState(() {
      _ending = true;
      _speaking = true;
      _highlightStart = -1;
      _highlightEnd = -1;
    });

    // P0 placement_ended (manual_exit)
    final userId = ref.read(chatProvider).valueOrNull?.memory.childId ?? '';
    final s = ref.read(placementProvider);
    final studentTurns =
        s.messages.where((m) => m.sender == MessageSender.child).length;
    final startedAt = _placementStartedAt ?? DateTime.now();
    AnalyticsService.logPlacementEnded(
      userId: userId,
      placementAttemptId: '${userId}_${startedAt.millisecondsSinceEpoch}',
      endState: 'manual_exit',
      studentTurns: studentTurns,
      startedAt: startedAt,
      endedAt: DateTime.now(),
    );

    try {
      await ref.read(placementProvider.notifier).endConversation();
    } catch (e) {
      _snack(e);
    }

    if (!mounted) return;

    // First stop any current speech explicitly to clear active playback
    final nativeTts = ref.read(nativeTtsProvider);
    await nativeTts.stop();
    // Allow any pending stop callback events to drain from the native channel
    await Future.delayed(const Duration(milliseconds: 150));

    // Safety net: force navigation after 4.5 seconds if TTS done callback fails
    final safetyTimer = Timer(
      const Duration(milliseconds: 4500),
      _goToComplete,
    );

    // Listen for TTS done stream to transition as soon as speech finishes
    StreamSubscription? doneSub;
    doneSub = nativeTts.doneStream.listen((_) {
      safetyTimer.cancel();
      doneSub?.cancel();
      Future.delayed(const Duration(milliseconds: 400), _goToComplete);
    });

    try {
      await nativeTts.speak(_closingLine());
    } catch (_) {
      safetyTimer.cancel();
      doneSub.cancel();
      _goToComplete();
    }
  }

  void _snack(Object e) {
    if (!mounted) return;
    OfflineAlertPopup.show(context);
  }

  // Proportional progress placeholder: fraction of the (assumed) turn target
  // that Zoe has already asked, or a full bar once the screening completes.
  double _progress(PlacementState s) {
    if (s.isComplete) return 1.0;
    final zoeTurns = s.messages
        .where((m) => m.sender == MessageSender.zoe)
        .length;
    return (zoeTurns / kPlacementTurnTarget).clamp(0.0, 1.0);
  }

  String? _lastFrom(PlacementState s, MessageSender who) {
    for (final m in s.messages.reversed) {
      if (m.sender == who) return m.text;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(placementProvider, (previous, next) {
      if (next.status == ChatStatus.zoeSpeaking) {
        setState(() {
          _speaking = true;
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
    final s = ref.watch(placementProvider);
    final isOnline = ref.watch(connectivityProvider).value ?? true;
    _maybeAdvance(s);

    final hasTurn = s.messages.any((m) => m.sender != MessageSender.system);
    final ConvPhase phase;
    if (_ending) {
      phase = ConvPhase.ending;
    } else if (hasTurn) {
      phase = ConvPhase.talking;
    } else {
      phase = ConvPhase.prepare;
    }

    final micState = switch (s.status) {
      ChatStatus.userSpeaking => MicState.listening,
      ChatStatus.zoeThinking => MicState.busy,
      ChatStatus.zoeSpeaking => MicState.idle, // Allow interrupt — user can tap to cut in
      ChatStatus.offline || ChatStatus.idle || ChatStatus.speechError => MicState.idle,
    };

    // While ending, Zoe speaks the fixed farewell (which cross-fades in over the
    // last turn); otherwise show her latest line.
    final zoeLine = _ending ? _closingLine() : _lastFrom(s, MessageSender.zoe);

    // In this voice-first flow, student transcription bubbles are hidden fully at all times.
    const String? studentLine = null;
    const bool studentLive = false;

    final speechLevel = ref.watch(sttLevelProvider);

    return PopScope(
      canPop: true,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: EllaColors.surfaceVariant,
        body: s.error != null && s.messages.isEmpty
            ? HomeSceneBackground(
                child: Center(
                  child: Text(
                    s.error!,
                    style: const TextStyle(color: EllaColors.ink),
                  ),
                ),
              )
            : ConversationView(
                phase: phase,
                mascotSpeaking:
                    _ending ||
                    s.status == ChatStatus.zoeSpeaking ||
                    _replaying ||
                    _speaking,
                mascotThinking: !_ending && s.status == ChatStatus.zoeThinking,
                isOffline: !isOnline,
                progress: _ending ? 1.0 : _progress(s),
                zoeLine: zoeLine,
                studentLine: studentLine,
                studentLive: studentLive,
                speechLevel: speechLevel,
                hasSpeechError: s.status == ChatStatus.speechError,
                micState: micState,
                textMode: _keyboardMode,
                textController: _textController,
                focusNode: _focusNode,
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
                onEnd: _exit,
                // Speaker dot on Zoe's bubble: replays the line when idle.
                // While she's already talking the tap is a no-op (never stops
                // or restarts her). Only Zoe's lines get the control — and not
                // the farewell (no replay dot while ending).
                onSpeakAgain:
                    (!_ending && zoeLine != null && zoeLine.trim().isNotEmpty)
                    ? () => _speakLine(zoeLine)
                    : null,
                highlightStart: _highlightStart,
                highlightEnd: _highlightEnd,
              ),
      ),
    );
  }

  /// Replays a Zoe line via TTS. While TTS is already speaking, tapping it stops
  /// (mutes) the speech. Sets [_replaying] around the playback so Zoe runs her
  /// speaking animation for the manual replay too.
  Future<void> _speakLine(String text) async {
    if (_speaking || _replaying) {
      _stopAllTts();
      return;
    }
    setState(() {
      _replaying = true;
      _speaking = true;
      _highlightStart = -1;
      _highlightEnd = -1;
    });
    try {
      await ref.read(placementProvider.notifier).replayZoeLine(text);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _replaying = false);
    }
  }
}
