// Session Call — the voice-first conversation screen (new garden design). Thin
// wiring over ConversationView: maps the live ChatState → display inputs and
// hands the existing chatProvider methods back as callbacks. All look/feel lives
// in ConversationView; the engine/state machine is unchanged.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_toast.dart';
import '../../core/offline_alert_popup.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../core/topic_data.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/garden_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/stt_tts_service.dart';
import 'widgets/conversation_view.dart';
import 'widgets/mascot_loading_screen.dart';
import 'widgets/need_to_go_sheet.dart';
import 'widgets/network_error_view.dart';
import '../../services/sounds.dart';
import 'home_screen.dart' show kHomeChildName;

const String _kGoodbye = 'It was great talking to you. See you again later!';
const String _kPreviewZoeLine =
    'That sounds like a lovely day. What was your favorite part?';
const String _kPreviewStudentLine =
    'My favorite part was playing outside with my cousins.';

typedef _ConversationPreviewSelection = ({
  GardenPreviewConversationOutcome outcome,
  Duration judgeDelay,
});

class SessionScreen extends ConsumerStatefulWidget {
  final String? introText;
  final VoidCallback? onEnded;
  final bool previewMode;

  /// When set (a topic tapped on the home screen), overrides the engine's topic
  /// pick for this session's POST /session; otherwise the engine chooses.
  final Topic? initialTopic;

  const SessionScreen({
    super.key,
    this.introText,
    this.onEnded,
    this.initialTopic,
    this.previewMode = false,
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
  Duration _previewJudgeDelay = const Duration(seconds: 8);

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
  late final ChatNotifier? _chatNotifier;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _chatNotifier = widget.previewMode ? null : ref.read(chatProvider.notifier);
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
    try {
      _chatNotifier?.stopListening();
      _tts.stop();
    } catch (_) {}
    _textController.dispose();
    super.dispose();
  }

  void _maybeStartSession() {
    if (widget.previewMode || _sessionStarted) return;
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
    Future.delayed(const Duration(milliseconds: 300), () {
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
  Future<void> _endConversation({
    GardenPreviewConversationOutcome? previewOutcome,
    Duration? previewDelay,
  }) async {
    if (_ending) return;
    setState(() {
      _ending = true;
      _paused = false;
      _sheetOpen = false;
      _speaking = true;
    });
    _navigated = true; // Prevent _maybeAdvance from scheduling a duplicate pop
    
    if (!widget.previewMode) {
      final notifier = ref.read(chatProvider.notifier);
      await notifier.stopListening();
      
      // Fire scoring in the background (don't wait)
      unawaited(notifier.endChat().catchError(_snack));
    }

    // First stop any current speech explicitly to clear active playback
    final nativeTts = ref.read(nativeTtsProvider);
    await nativeTts.stop();
    // Allow any pending stop callback events to drain from the native channel
    await Future.delayed(const Duration(milliseconds: 150));

    // Scoring stays off the critical path. Starting it only after the previous
    // utterance has stopped also prevents endChat from retaining that stale
    // speaking-message id in the state it snapshots.
    if (widget.previewMode) {
      ref
          .read(gardenConversationPreviewControllerProvider)
          .start(
            outcome:
                previewOutcome ?? GardenPreviewConversationOutcome.watering,
            judgeDelay: previewDelay ?? _previewJudgeDelay,
          );
    } else {
      unawaited(notifier!.endChat().catchError(_snack));
    }

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

    _navigated = true;
    final onEnded = widget.onEnded;
    Navigator.of(context).pop();
    if (onEnded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onEnded());
    }
  }

  Future<void> _showConversationPreviewSheet() async {
    if (!widget.previewMode || _ending) return;
    final selection = await showModalBottomSheet<_ConversationPreviewSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConversationOutcomePreviewSheet(
        initialDelay: _previewJudgeDelay,
        onDelayChanged: (delay) => _previewJudgeDelay = delay,
      ),
    );
    if (!mounted || selection == null) return;
    setState(() => _previewJudgeDelay = selection.judgeDelay);
    await _endConversation(
      previewOutcome: selection.outcome,
      previewDelay: selection.judgeDelay,
    );
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
      // The pause sheet is gone; Zoe speaks the farewell before navigation.
      await _endConversation();
      return;
    }

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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.previewMode) return _buildPreviewConversation();

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

  Widget _buildPreviewConversation() {
    return PopScope(
      canPop: !_ending,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: EllaColors.surfaceVariant,
        body: ConversationView(
          phase: _ending ? ConvPhase.ending : ConvPhase.talking,
          mascotSpeaking: _ending || _replaying || _speaking,
          zoeLine: _ending ? _kGoodbye : _kPreviewZoeLine,
          studentLine: _ending ? null : _kPreviewStudentLine,
          micState: _ending ? MicState.busy : MicState.idle,
          onEnd: _endConversation,
          onEndLongPress: _showConversationPreviewSheet,
          onSpeakAgain: _ending ? null : () => _speakLine(_kPreviewZoeLine),
          highlightStart: _highlightStart,
          highlightEnd: _highlightEnd,
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
      ChatStatus.idle || ChatStatus.offline => MicState.idle,
    };

    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

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
      micState: micState,
      textMode: _keyboardMode,
      textController: _textController,
      onMic: isOnline ? () => _onMic(s) : () {
        OfflineAlertPopup.show(context);
      },
      onToggleKeyboard: isOnline ? _toggleKeyboard : () {
        OfflineAlertPopup.show(context);
      },
      onSend: isOnline ? _sendTyped : () {
        OfflineAlertPopup.show(context);
      },
      onEnd: _endConversation,
      onEndLongPress: null,
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
    try {
      await tts.speak(text);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _replaying = false);
    }
  }
}

class _ConversationOutcomePreviewSheet extends StatefulWidget {
  final Duration initialDelay;
  final ValueChanged<Duration> onDelayChanged;

  const _ConversationOutcomePreviewSheet({
    required this.initialDelay,
    required this.onDelayChanged,
  });

  @override
  State<_ConversationOutcomePreviewSheet> createState() =>
      _ConversationOutcomePreviewSheetState();
}

class _ConversationOutcomePreviewSheetState
    extends State<_ConversationOutcomePreviewSheet> {
  static const _delays = [
    Duration.zero,
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 12),
  ];

  GardenPreviewConversationOutcome _outcome =
      GardenPreviewConversationOutcome.watering;
  late Duration _delay = widget.initialDelay;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('conversation-preview-outcome-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: EllaColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EllaColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Preview conversation result',
                      style: EllaTextStyles.titleSmall,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('conversation-preview-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
              Text(
                'Choose the judge result that should arrive after Zoe says goodbye.',
                style: EllaTextStyles.bodySmall.copyWith(
                  color: EllaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              for (final outcome in GardenPreviewConversationOutcome.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PreviewOutcomeTile(
                    outcome: outcome,
                    selected: _outcome == outcome,
                    onTap: () => setState(() => _outcome = outcome),
                  ),
                ),
              const SizedBox(height: 8),
              Text('Judge delay', style: EllaTextStyles.bodySemiboldLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final delay in _delays)
                    ChoiceChip(
                      key: ValueKey(
                        'conversation-preview-delay-${delay.inSeconds}',
                      ),
                      label: Text(
                        delay == Duration.zero
                            ? 'Immediate'
                            : '${delay.inSeconds}s',
                      ),
                      selected: _delay == delay,
                      onSelected: (_) {
                        setState(() => _delay = delay);
                        widget.onDelayChanged(delay);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _outcome == GardenPreviewConversationOutcome.quickHello
                    ? 'Quick hello never shows speculative watering while it waits.'
                    : 'The timer starts now, before the farewell, just like the live judge.',
                style: EllaTextStyles.caption.copyWith(
                  color: EllaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('conversation-preview-run'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((outcome: _outcome, judgeDelay: _delay)),
                  style: FilledButton.styleFrom(
                    backgroundColor: EllaColors.berryDark,
                    foregroundColor: EllaColors.onPrimary,
                  ),
                  child: const Text('End preview conversation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewOutcomeTile extends StatelessWidget {
  final GardenPreviewConversationOutcome outcome;
  final bool selected;
  final VoidCallback onTap;

  const _PreviewOutcomeTile({
    required this.outcome,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? EllaColors.greenLight : EllaColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('conversation-preview-outcome-${outcome.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? EllaColors.greenDeep : EllaColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? EllaColors.greenDeep
                    : EllaColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outcome.label,
                      style: EllaTextStyles.bodySemiboldLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      outcome.description,
                      style: EllaTextStyles.bodySmall.copyWith(
                        color: EllaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
