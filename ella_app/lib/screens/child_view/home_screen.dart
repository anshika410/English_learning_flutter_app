// Home / Talk screen — Figma "Homescreen — Fallback".
// A warm lamp-lit room: hanging lamp, Zoe in a brown ring, a cream greeting
// bubble (callback + today's proposed topic, derived live from memory), and a
// "Start Talking" CTA that opens the voice-first Session screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine.dart';
import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';
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

  // "Yesterday, we talked about X. Today, I wanted to talk about Y. Shall we?"
  String _greeting(MemoryState? mem) {
    if (mem == null) return 'Getting things ready…';
    final proposal = pickTopic(mem)?.topic;
    final callback = mem.lastTopics.isNotEmpty ? mem.lastTopics.first : null;
    final parts = <String>[];
    if (callback != null) {
      parts.add('Yesterday, we talked about $callback.');
    }
    if (proposal != null) {
      parts.add('Today, I wanted to talk about $proposal. Shall we?');
    } else if (callback != null) {
      parts.add('Want to keep going?');
    } else {
      parts.add("Let's talk about something fun today. Shall we?");
    }
    return parts.join(' ');
  }

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
                    text: _greeting(memory),
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
