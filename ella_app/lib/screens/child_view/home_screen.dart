// Home / Talk screen — Figma "Homescreen — Fallback".
// A warm lamp-lit room: hanging lamp, Zoe in a brown ring, a cream greeting
// bubble (callback + today's proposed topic, derived live from memory), and a
// "Start Talking" CTA that opens the voice-first Session screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';
import 'session_intro.dart';
import 'session_screen.dart';
import 'widgets/ella_primary_button.dart';
import 'widgets/room_background.dart';
import 'widgets/speech_bubble.dart';
import 'widgets/zoe_mascot.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onConversationEnded;

  const HomeScreen({super.key, this.onConversationEnded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatProvider);
    return chatAsync.when(
      data: (s) => _HomeBody(
        memory: s.memory,
        onConversationEnded: onConversationEnded,
      ),
      loading: () => _HomeBody(
        memory: null,
        onConversationEnded: onConversationEnded,
      ),
      error: (e, _) => RoomBackground(
        child: Center(
          child: Text('Home error: $e',
              style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  final MemoryState? memory;
  final VoidCallback? onConversationEnded;
  const _HomeBody({
    required this.memory,
    required this.onConversationEnded,
  });

  Future<void> _startTalking(BuildContext context, WidgetRef ref) async {
    final chatState = ref.read(chatProvider);
    if (chatState.hasValue && chatState.requireValue.sessionEnded) {
      await ref.read(chatProvider.notifier).nextChat();
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(onEnded: onConversationEnded),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoomBackground(
      // Push the tan/brown divider down so the greeting bubble sits across it
      // (its top edge on tan, the rest on brown) as in the Figma home screen.
      splitAt: 0.73,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mascotSize = (constraints.maxWidth * 0.74).clamp(240.0, 330.0);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  const Spacer(flex: 9),
                  ZoeMascot(
                    mood: MascotMood.greeting,
                    size: mascotSize,
                  ),
                  const Spacer(flex: 2),
                  SpeechBubble(
                    text: buildHomeGreeting(memory),
                    showTail: true,
                    footer: EllaPrimaryButton(
                      label: 'Start Talking',
                      onTap: memory == null
                          ? null
                          : () => _startTalking(context, ref),
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
