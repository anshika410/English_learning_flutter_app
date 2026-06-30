// Session Call — Figma voice-first conversation screen.
// Room backdrop + END (top-right) + animated Zoe + a cream speech bubble showing
// Zoe's latest line + a keyboard toggle and the mango mic ("Tap to Speak").
// Wired to the real engine via chatProvider. No message list / testing controls
// (those live in child_chat_screen behind the Glass Box flag).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme_colors.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import 'widgets/room_background.dart';
import 'widgets/speech_bubble.dart';
import 'widgets/zoe_mascot.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final String? introText;
  final VoidCallback? onEnded;

  const SessionScreen({super.key, this.introText, this.onEnded});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _textController = TextEditingController();
  final _textFocus = FocusNode();
  bool _sessionStarted = false;
  bool _keyboardMode = false;

  @override
  void dispose() {
    ref.read(chatProvider.notifier).stopListening();
    _textController.dispose();
    _textFocus.dispose();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Allow fresh session if returning to this screen after chat end
  }

  // ── Mood + latest line ──────────────────────────────────────────────────────

  MascotMood _moodFor(ChatStatus status) {
    switch (status) {
      case ChatStatus.zoeSpeaking:
        return MascotMood.speaking;
      case ChatStatus.zoeThinking:
        return MascotMood.thinking;
      case ChatStatus.userSpeaking:
      case ChatStatus.idle:
        return MascotMood.listening;
    }
  }

  String _latestZoeLine(ChatState s) {
    for (final m in s.messages.reversed) {
      if (m.sender == MessageSender.zoe) return m.text;
    }
    if (s.status == ChatStatus.zoeThinking) return '…';
    return widget.introText ?? 'Ready when you are. Shall we?';
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _onMicTap(ChatState s) {
    final notifier = ref.read(chatProvider.notifier);
    if (s.status == ChatStatus.userSpeaking) {
      notifier.stopListening();
    } else if (s.status == ChatStatus.idle && !s.sessionEnded) {
      notifier.startListening().catchError(_snack);
    }
  }

  void _toggleKeyboard() {
    setState(() => _keyboardMode = !_keyboardMode);
    if (_keyboardMode) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _textFocus.requestFocus();
      });
    } else {
      _textFocus.unfocus();
    }
  }

  void _sendTyped() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _keyboardMode = false);
    _textFocus.unfocus();
    ref.read(chatProvider.notifier).sendUserTurn(text).catchError(_snack);
  }

  void _snack(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _confirmEnd() async {
    final s = ref.read(chatProvider);
    final hasTurns = s.hasValue &&
        s.requireValue.messages
            .any((m) => m.sender != MessageSender.system);
    if (!hasTurns) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End the chat?'),
        content: const Text(
            "Zoe will score this conversation and update your garden."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep talking')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(chatProvider.notifier).endChat().catchError(_snack);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onEnded?.call();
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen(chatProvider, (_, _) => _maybeStartSession());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartSession());

    final chatAsync = ref.watch(chatProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: EllaColors.roomWallBottom,
      body: RoomBackground(
        child: SafeArea(
          child: chatAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white)),
            error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.white))),
            data: (s) {
              final showPartial = s.status == ChatStatus.userSpeaking &&
                  (s.partialStt?.isNotEmpty ?? false);
              return LayoutBuilder(
                builder: (context, constraints) {
                  final mascotSize =
                      (constraints.maxWidth * 0.64).clamp(230.0, 275.0);
                  return Column(
                    children: [
                  // END button, top-right
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 22, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _EndButton(onTap: _confirmEnd),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.07),
                  // Zoe mascot (Figma proportions)
                  ZoeMascot(mood: _moodFor(s.status), size: mascotSize),
                  SizedBox(height: constraints.maxHeight * 0.05),
                  // Speech bubble with pointer to Zoe (Figma design)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SpeechBubble(
                      text: showPartial ? s.partialStt! : _latestZoeLine(s),
                      italic: showPartial,
                      showTail: true,
                    ),
                  ),
                  const Spacer(),
                  // Keyboard or Mic row at bottom
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 0, 40, 22),
                    child: _keyboardMode
                        ? _KeyboardRow(
                            controller: _textController,
                            focusNode: _textFocus,
                            onBack: _toggleKeyboard,
                            onSend: _sendTyped,
                          )
                        : _MicRow(
                            status: s.status,
                            onKeyboard: _toggleKeyboard,
                            onMic: () => _onMicTap(s),
                          ),
                  ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── END button (cream pill, Figma style) ──────────────────────────────────────

class _EndButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EndButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: EllaColors.bubbleSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(6),
            bottomLeft: Radius.circular(18),
          ),
          border: Border.all(color: EllaColors.mangoLight, width: 1.5),
        ),
        child: Text(
          'END',
          style: GoogleFonts.baloo2(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: EllaColors.mangoDark,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ── Mic row (keyboard toggle + mic + "Tap to Speak") ──────────────────────────

class _MicRow extends StatelessWidget {
  final ChatStatus status;
  final VoidCallback onKeyboard;
  final VoidCallback onMic;

  const _MicRow({
    required this.status,
    required this.onKeyboard,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    final isListening = status == ChatStatus.userSpeaking;
    final isBusy =
        status == ChatStatus.zoeThinking || status == ChatStatus.zoeSpeaking;

    final keyboardBtn = GestureDetector(
      onTap: onKeyboard,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: EllaColors.bubbleSurface,
          border: Border.all(color: EllaColors.border, width: 1.5),
        ),
        child: const Icon(Icons.keyboard_alt_outlined,
            size: 22, color: EllaColors.secondary),
      ),
    );

    final micBtn = GestureDetector(
      onTap: isBusy ? null : onMic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isBusy
              ? EllaColors.muted
              : isListening
                  ? EllaColors.mangoDark
                  : EllaColors.mangoMain,
          border: Border.all(color: EllaColors.mangoDark, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: EllaColors.mangoDeepest.withValues(alpha: 0.4),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          size: 30,
          color: Colors.white,
        ),
      ),
    );

    final label = Text(
      isBusy
          ? 'Zoe is talking…'
          : isListening
              ? 'Listening…'
              : 'Tap to Speak',
      style: GoogleFonts.baloo2(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: EllaColors.surface,
        letterSpacing: 0.6,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(alignment: Alignment.centerLeft, child: keyboardBtn),
              Center(child: micBtn),
            ],
          ),
        ),
        const SizedBox(height: 8),
        label,
      ],
    );
  }
}

// ── Keyboard row (text input) ─────────────────────────────────────────────────

class _KeyboardRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBack;
  final VoidCallback onSend;

  const _KeyboardRow({
    required this.controller,
    required this.focusNode,
    required this.onBack,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EllaColors.bubbleSurface,
              border: Border.all(color: EllaColors.border, width: 1.5),
            ),
            child: const Icon(Icons.mic_rounded,
                size: 22, color: EllaColors.secondary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.send,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => onSend(),
            style: GoogleFonts.baloo2(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: EllaColors.primary,
            ),
            decoration: InputDecoration(
              hintText: 'Type your reply…',
              hintStyle: GoogleFonts.baloo2(
                  fontSize: 15, color: EllaColors.muted),
              filled: true,
              fillColor: EllaColors.bubbleSurface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                    color: EllaColors.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                    color: EllaColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                    color: EllaColors.mangoMain, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSend,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EllaColors.mangoMain,
              border: Border.all(color: EllaColors.mangoDark, width: 2),
            ),
            child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
