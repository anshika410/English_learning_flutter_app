// Child View — port of the simulator's left panel.
// Layout (top → bottom):
//   1. AppBar with mode-toggle pill (micro-skill ⟷ units)
//   2. Status line (Chat #N · mode · level · turns · lifetime · LLM)
//   3. Garden
//   4. GrewBanner (when sessionEnded && lastChanges)
//   5. Message list (Zoe / child / sys)
//   6. Input dock (auto button OR voice/text OR session-ended new-chat)
//   7. Control row (auto, End chat & judge, Next chat, Reset)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import 'chat_bubble.dart';

// The progression-model (micro-skill ⟷ units) toggle is cosmetic while the
// live conversation framing is decided server-side. Hidden until the backend
// accepts a progression_model on session creation. Flip to true to restore.
const bool kShowModePill = false;

class ChildChatScreen extends ConsumerStatefulWidget {
  const ChildChatScreen({super.key});

  @override
  ConsumerState<ChildChatScreen> createState() => _ChildChatScreenState();
}

class _ChildChatScreenState extends ConsumerState<ChildChatScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  bool _sessionStarted = false;

  @override
  void dispose() {
    _scrollController.dispose();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatProvider, (_, next) {
      _maybeStartSession();
      if (next.hasValue) _scrollToBottom();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartSession());

    final chatAsync = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Zoe',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (kShowModePill)
            chatAsync.when(
              data: (s) => _ModePill(
                mode: s.memory.progressionModel,
                onChange: (m) => _confirmModeChange(context, m),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Status line
          chatAsync.when(
            data: (s) => _StatusLine(state: s),
            loading: () => const SizedBox(height: 22),
            error: (_, _) => const SizedBox(height: 22),
          ),

          Expanded(
            child: chatAsync.when(
              data: (s) => _MessageList(
                messages: s.messages,
                isZoeThinking: s.status == ChatStatus.zoeThinking,
                scrollController: _scrollController,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),

          // Input dock
          chatAsync.when(
            data: (s) => _InputDock(
              state: s,
              textController: _textController,
              onSend: (text) {
                _textController.clear();
                ref.read(chatProvider.notifier).sendUserTurn(text);
              },
              onToggleMode: () =>
                  ref.read(chatProvider.notifier).toggleInputMode(),
              onMicTap: () => _onMicTap(s),
              onAutoTurn: () =>
                  ref.read(chatProvider.notifier).autoTurn().catchError(_snack),
              onNextChat: () =>
                  ref.read(chatProvider.notifier).nextChat().catchError(_snack),
            ),
            loading: () => const SizedBox(height: 80),
            error: (_, _) => const SizedBox(height: 80),
          ),

          // Bottom control row
          chatAsync.when(
            data: (s) => _ControlRow(
              autoMode: s.autoMode,
              canEndChat:
                  s.messages
                      .where((m) => m.sender != MessageSender.system)
                      .isNotEmpty &&
                  !s.sessionEnded &&
                  s.status == ChatStatus.idle,
              canNextChat: s.sessionEnded,
              onToggleAuto: () =>
                  ref.read(chatProvider.notifier).setAutoMode(!s.autoMode),
              onEndChat: () => _confirmEndChat(context),
              onNextChat: () =>
                  ref.read(chatProvider.notifier).nextChat().catchError(_snack),
              onReset: () => _confirmReset(context),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Mic ────────────────────────────────────────────────────────────────────

  void _onMicTap(ChatState s) {
    if (s.status == ChatStatus.userSpeaking) {
      ref.read(chatProvider.notifier).stopListening();
    } else if (s.status == ChatStatus.idle) {
      ref
          .read(chatProvider.notifier)
          .startListening()
          .catchError((e) => _snack(e));
    }
  }

  void _snack(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ── Confirms ──────────────────────────────────────────────────────────────

  Future<void> _confirmEndChat(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End chat?'),
        content: const Text(
          'Zoe will score the conversation and your garden will update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End chat'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ref.read(chatProvider.notifier).endChat().catchError(_snack);
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset everything?'),
        content: const Text(
          'Wipes in-memory state, snapshots, sessions, and history. '
          'The Supabase row stays untouched until the next End Chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      _sessionStarted = false;
      ref.read(chatProvider.notifier).resetAll().catchError(_snack);
    }
  }

  Future<void> _confirmModeChange(BuildContext context, String mode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Switch progression model?'),
        content: Text(
          'Wipes in-memory state and starts a fresh chat in '
          '"$mode" mode. Supabase row is not touched until next End Chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      _sessionStarted = false;
      ref
          .read(chatProvider.notifier)
          .setProgressionModel(mode)
          .catchError(_snack);
    }
  }
}

// ── Mode pill (micro-skill | units) ─────────────────────────────────────────

class _ModePill extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChange;
  const _ModePill({required this.mode, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeBtn('micro-skill', mode == 'micro-skill'),
          _modeBtn('units', mode == 'units'),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, bool selected) {
    return GestureDetector(
      onTap: selected ? null : () => onChange(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF4CAF50) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ── Status line ──────────────────────────────────────────────────────────────

class _StatusLine extends StatelessWidget {
  final ChatState state;
  const _StatusLine({required this.state});

  @override
  Widget build(BuildContext context) {
    final mem = state.memory;
    final llm = state.liveLlmLastCall ? 'live' : 'mock';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      color: Colors.black.withValues(alpha: 0.18),
      child: Text(
        'Chat #${state.chatNumber} · ${mem.progressionModel} · ${mem.level}'
        ' · turns: ${state.turnCount} · lifetime: ${mem.effortTimesSpoken}'
        ' · LLM: $llm',
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}

// ── Message list ────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isZoeThinking;
  final ScrollController scrollController;

  const _MessageList({
    required this.messages,
    required this.isZoeThinking,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final count = messages.length + (isZoeThinking ? 1 : 0);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: count,
      itemBuilder: (ctx, i) {
        if (i == messages.length && isZoeThinking) {
          return const ThinkingBubble();
        }
        final m = messages[i];
        if (m.sender == MessageSender.system) {
          return _SysBubble(text: m.text);
        }
        return ChatBubble(message: m);
      },
    );
  }
}

class _SysBubble extends StatelessWidget {
  final String text;
  const _SysBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade100.withValues(alpha: 0.85),
        border: Border.all(color: Colors.amber.shade700, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Color(0xFF7A5A13)),
      ),
    );
  }
}

// ── Input dock ──────────────────────────────────────────────────────────────

class _InputDock extends StatelessWidget {
  final ChatState state;
  final TextEditingController textController;
  final void Function(String) onSend;
  final VoidCallback onToggleMode;
  final VoidCallback onMicTap;
  final VoidCallback onAutoTurn;
  final VoidCallback onNextChat;

  const _InputDock({
    required this.state,
    required this.textController,
    required this.onSend,
    required this.onToggleMode,
    required this.onMicTap,
    required this.onAutoTurn,
    required this.onNextChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.sessionEnded)
            ElevatedButton.icon(
              onPressed: onNextChat,
              icon: const Text('🌱', style: TextStyle(fontSize: 16)),
              label: const Text('Start a new chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4CAF50),
                minimumSize: const Size(double.infinity, 44),
              ),
            )
          else if (state.autoMode)
            ElevatedButton.icon(
              onPressed: state.status == ChatStatus.idle ? onAutoTurn : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                state.autoStep >= kAutoMaxTurns
                    ? 'End chat'
                    : 'Next turn (${state.autoStep}/$kAutoMaxTurns)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4CAF50),
                minimumSize: const Size(double.infinity, 44),
              ),
            )
          else ...[
            _ModePills(mode: state.inputMode, onToggle: onToggleMode),
            const SizedBox(height: 8),
            if (state.partialStt != null && state.partialStt!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  state.partialStt!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (state.inputMode == InputMode.voice)
              _MicButton(status: state.status, onTap: onMicTap)
            else
              _TextInputRow(
                controller: textController,
                enabled: state.status == ChatStatus.idle,
                onSend: onSend,
              ),
          ],
        ],
      ),
    );
  }
}

class _ModePills extends StatelessWidget {
  final InputMode mode;
  final VoidCallback onToggle;
  const _ModePills({required this.mode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Pill(label: 'Voice', selected: mode == InputMode.voice),
            _Pill(label: 'Text', selected: mode == InputMode.text),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  const _Pill({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFF4CAF50) : Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final ChatStatus status;
  final VoidCallback onTap;
  const _MicButton({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isListening = status == ChatStatus.userSpeaking;
    final isBusy =
        status == ChatStatus.zoeThinking || status == ChatStatus.zoeSpeaking;
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isBusy
              ? Colors.white24
              : isListening
              ? const Color(0xFFB55233)
              : const Color(0xFF4CAF50),
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _TextInputRow extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSend;

  const _TextInputRow({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Type your reply…',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onSubmitted: enabled ? (t) => onSend(t) : null,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: enabled ? () => onSend(controller.text) : null,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? const Color(0xFF4CAF50) : Colors.white24,
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bottom control row (auto · end · next · reset) ──────────────────────────

class _ControlRow extends StatelessWidget {
  final bool autoMode;
  final bool canEndChat;
  final bool canNextChat;
  final VoidCallback onToggleAuto;
  final VoidCallback onEndChat;
  final VoidCallback onNextChat;
  final VoidCallback onReset;

  const _ControlRow({
    required this.autoMode,
    required this.canEndChat,
    required this.canNextChat,
    required this.onToggleAuto,
    required this.onEndChat,
    required this.onNextChat,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      color: Colors.black.withValues(alpha: 0.15),
      child: Row(
        children: [
          _btn(
            label: autoMode ? '✋ manual' : '🤖 auto',
            onTap: onToggleAuto,
            primary: false,
          ),
          const SizedBox(width: 6),
          _btn(
            label: 'End ⚖️',
            onTap: canEndChat ? onEndChat : null,
            primary: true,
          ),
          const SizedBox(width: 6),
          _btn(
            label: 'Next →',
            onTap: canNextChat ? onNextChat : null,
            primary: false,
          ),
          const SizedBox(width: 6),
          _btn(label: 'Reset', onTap: onReset, primary: false),
        ],
      ),
    );
  }

  Widget _btn({
    required String label,
    VoidCallback? onTap,
    required bool primary,
  }) {
    final enabled = onTap != null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? (primary ? const Color(0xFF4CAF50) : Colors.white)
                : Colors.white24,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled
                  ? (primary ? Colors.white : const Color(0xFF2E7D32))
                  : Colors.white60,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
