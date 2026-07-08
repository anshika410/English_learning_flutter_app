// Placement conversation — the voice screening turns (Figma "Placement Flow").
// Thin wiring over ConversationView, mirroring SessionScreen but driven by
// placementProvider instead of chatProvider. When the backend signals the test
// is complete (or the child ends the chat), it hands off to the
// PlacementGardenScreen, which resolves into the bloom or sprout branch.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_colors.dart';
import '../../models/message.dart';
import '../../providers/placement_provider.dart';
import '../../providers/chat_provider.dart' show ChatStatus;
import '../../providers/service_providers.dart';
import 'placement_garden_screen.dart';
import 'widgets/conversation_view.dart';
import 'widgets/garden_sky_background.dart';

class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});

  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends ConsumerState<PlacementScreen> {
  final _textController = TextEditingController();
  bool _keyboardMode = false;
  bool _navigated = false;
  bool _advanceTimerStarted = false;

  @override
  void dispose() {
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

  // End the placement screening immediately (hard end — no farewell turn):
  // the notifier stops voice, marks the test complete and refreshes memory to
  // check whether a level was persisted, then we route straight to the
  // placement garden, which branches on that level (bloom vs sprout). Repeat
  // taps are absorbed by the notifier's `ending` guard + _navigated.
  Future<void> _exit() async {
    // If the screening already finished, End means "go to my garden" — route to
    // the placement garden instead of re-ending.
    if (ref.read(placementProvider).isComplete) {
      _goToComplete();
      return;
    }
    try {
      await ref.read(placementProvider.notifier).endConversation();
    } catch (e) {
      _snack(e);
    }
    // No closing line to let land — advance right away.
    _goToComplete();
  }

  void _snack(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String? _lastFrom(PlacementState s, MessageSender who) {
    for (final m in s.messages.reversed) {
      if (m.sender == who) return m.text;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
    final s = ref.watch(placementProvider);
    _maybeAdvance(s);

    final hasTurn = s.messages.any((m) => m.sender != MessageSender.system);
    final phase = hasTurn ? ConvPhase.talking : ConvPhase.prepare;

    final micState = switch (s.status) {
      ChatStatus.userSpeaking => MicState.listening,
      ChatStatus.zoeThinking || ChatStatus.zoeSpeaking => MicState.busy,
      ChatStatus.idle => MicState.idle,
    };

    final zoeLine = _lastFrom(s, MessageSender.zoe);
    String? studentLine;
    bool studentLive = false;
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
                mascotSpeaking: s.status == ChatStatus.zoeSpeaking,
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
                onEnd: _exit,
                // Speaker dot on Zoe's bubble: replays the line when idle.
                // While she's already talking the tap is a no-op (never stops
                // or restarts her). Only Zoe's lines get the control.
                onSpeakAgain: (zoeLine != null && zoeLine.trim().isNotEmpty)
                    ? () => _speakLine(zoeLine)
                    : null,
                highlightStart: s.highlightStart,
                highlightEnd: s.highlightEnd,
              ),
      ),
    );
  }

  /// Replays a Zoe line via TTS. A no-op while TTS is already speaking, so a
  /// tap can never restart or stack utterances.
  Future<void> _speakLine(String text) async {
    await ref.read(placementProvider.notifier).replayZoeLine(text);
  }
}
