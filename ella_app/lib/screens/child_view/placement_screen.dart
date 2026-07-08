// Placement conversation — the voice screening turns (Figma "Placement Flow").
// Thin wiring over ConversationView, mirroring SessionScreen but driven by
// placementProvider instead of chatProvider. When the backend signals the test
// is complete (or the child ends the chat), it hands off to the
// PlacementGardenScreen, which resolves into the bloom or sprout branch.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_toast.dart';
import '../../core/theme_colors.dart';
import '../../models/message.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/placement_provider.dart';
import '../../providers/chat_provider.dart' show ChatStatus;
import '../../providers/service_providers.dart';
import 'home_screen.dart' show kHomeChildName;
import 'placement_garden_screen.dart';
import 'widgets/conversation_view.dart';
import 'widgets/garden_sky_background.dart';

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
  bool _keyboardMode = false;
  bool _navigated = false;
  bool _advanceTimerStarted = false;

  // True while the End-Call closing line is playing (before we hand off to the
  // placement garden). Drives the ending phase: Zoe speaks a fixed farewell that
  // cross-fades in over the last turn, the dock disappears, then a ~2s hold.
  bool _ending = false;

  // True while a tapped-speaker replay is speaking — drives Zoe's speaking
  // animation for manual replays (the engine status only covers auto-speech).
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
      if (mounted && _speaking) {
        setState(() {
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
    ref.read(placementProvider.notifier).stopListening();
    _textController.dispose();
    super.dispose();
  }

  void _maybeStart() {
    final s = ref.read(placementProvider);
    if (!s.started) ref.read(placementProvider.notifier).start();
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
        Future.delayed(const Duration(seconds: 5), _goToComplete);
      }
      return;
    }
    Future.delayed(const Duration(milliseconds: 1600), _goToComplete);
  }

  // Swap to the placement garden screen (guarded so it only runs once). Used by
  // the auto-advance and by the End button when the screening is already done —
  // so ending a finished test never falls through to the home underneath.
  void _goToComplete() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PlacementGardenScreen()),
    );
  }

  void _onMic(PlacementState s) {
    final notifier = ref.read(placementProvider.notifier);
    if (s.status == ChatStatus.userSpeaking) {
      notifier.stopListening();
    } else if (s.status == ChatStatus.idle && !s.isComplete) {
      notifier.startListening().catchError(_snack);
    }
  }

  void _toggleKeyboard() => setState(() => _keyboardMode = !_keyboardMode);

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
        ref.read(onboardingProvider).valueOrNull?.name ?? kHomeChildName;
    return 'It was really nice talking with you, $name! Let\'s talk again soon.';
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
    // If the screening already finished, End means "go to my garden" — route to
    // the placement garden instead of playing the farewell.
    if (ref.read(placementProvider).isComplete) {
      _goToComplete();
      return;
    }
    setState(() {
      _ending = true;
      _speaking = true;
      _highlightStart = -1;
      _highlightEnd = -1;
    });
    try {
      await ref.read(placementProvider.notifier).endConversation();
    } catch (e) {
      _snack(e);
    }
    // Speak the farewell with the speaking animation, then hold a beat so it can
    // land before the transition. Cap the total wait so a slow/failed TTS still
    // advances promptly.
    if (!mounted) return;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    try {
      await ref.read(ttsProvider).speak(_closingLine());
    } catch (_) {}
    if (!mounted) return;
    await Future.delayed(Duration(milliseconds: reducedMotion ? 0 : 800));
    _goToComplete();
  }

  void _snack(Object e) {
    if (!mounted) return;
    debugPrint('[Placement] $e');
    showEllaErrorToast(context);
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
      ChatStatus.zoeThinking || ChatStatus.zoeSpeaking => MicState.busy,
      ChatStatus.idle => MicState.idle,
    };

    // While ending, Zoe speaks the fixed farewell (which cross-fades in over the
    // last turn); otherwise show her latest line.
    final zoeLine = _ending ? _closingLine() : _lastFrom(s, MessageSender.zoe);
    String? studentLine;
    bool studentLive = false;
    if (!_ending) {
      if (s.status == ChatStatus.userSpeaking) {
        final p = s.partialStt?.trim() ?? '';
        studentLine = p.isEmpty ? null : p;
        studentLive = true;
      } else {
        final last = s.messages.isNotEmpty ? s.messages.last : null;
        if (last != null && last.sender == MessageSender.child) {
          studentLine = last.text;
        }
      }
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: EllaColors.surfaceVariant,
        body: s.error != null && s.messages.isEmpty
            ? GardenSkyBackground(
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
                    _ending || s.status == ChatStatus.zoeSpeaking || _replaying || _speaking,
                mascotThinking: !_ending && s.status == ChatStatus.zoeThinking,
                // Bar sits full as the screening closes.
                progress: _ending ? 1.0 : _progress(s),
                zoeLine: zoeLine,
                studentLine: studentLine,
                studentLive: studentLive,
                micState: micState,
                textMode: _keyboardMode,
                textController: _textController,
                onMic: () => _onMic(s),
                onToggleKeyboard: _toggleKeyboard,
                onSend: _sendTyped,
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

  /// Replays a Zoe line via TTS. A no-op while TTS is already speaking, so a
  /// tap can never restart or stack utterances. Sets [_replaying] around the
  /// playback so Zoe runs her speaking animation for the manual replay too.
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
    await ref.read(placementProvider.notifier).replayZoeLine(text);
  }
}
