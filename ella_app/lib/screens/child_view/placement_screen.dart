// Placement conversation — the voice screening turns (Figma "Placement Flow").
// Thin wiring over ConversationView, mirroring SessionScreen but driven by
// placementProvider instead of chatProvider. When the backend signals the test
// is complete, it hands off to the bloom PlacementCompleteScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_colors.dart';
import '../../models/message.dart';
import '../../providers/placement_provider.dart';
import '../../providers/chat_provider.dart' show ChatStatus;
import '../../providers/service_providers.dart';
import 'placement_complete_screen.dart';
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

  // On completion, let the closing line land for a beat, then swap to the bloom
  // screen (replace so back never returns into the finished test).
  void _maybeAdvance(PlacementState s) {
    if (!s.isComplete || _navigated) return;
    Future.delayed(const Duration(milliseconds: 1600), _goToComplete);
  }

  // Swap to the bloom completion screen (guarded so it only runs once). Used by
  // the auto-advance and by the End button when the screening is already done —
  // so ending a finished test never falls through to the home underneath.
  void _goToComplete() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PlacementCompleteScreen()),
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

  // End the placement screening: stop Zoe and leave the conversation, returning
  // to the placement intro. The screening state is reset when the intro starts
  // the next one (invalidating here would rebuild this screen mid-pop and
  // auto-restart a turn). The child stays gated on the intro until they finish a
  // placement.
  Future<void> _exit() async {
    // If the screening already finished, End means "go to my garden", not "drop
    // back to the intro" — route to the bloom screen instead of popping.
    if (ref.read(placementProvider).isComplete) {
      _goToComplete();
      return;
    }
    final notifier = ref.read(placementProvider.notifier);
    await notifier.stopSpeaking();
    await notifier.stopListening();
    if (mounted) Navigator.of(context).maybePop();
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
                onSpeakAgain: (zoeLine != null && zoeLine.trim().isNotEmpty)
                    ? () => _speakLine(zoeLine)
                    : null,
              ),
      ),
    );
  }

  Future<void> _speakLine(String text) async {
    final notifier = ref.read(placementProvider.notifier);
    await notifier.stopSpeaking();
    try {
      await ref.read(ttsProvider).speak(text);
    } catch (_) {}
  }
}
