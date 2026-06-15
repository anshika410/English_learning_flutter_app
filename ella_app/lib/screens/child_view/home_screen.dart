// Home / Talk screen — port of #home from ella-garden-nonlinear.html.
// Zoe greets the child (callback + recap + proposal) with one clear action.
// Greeting copy and the CTA are derived live from MemoryState; the child's
// name is a placeholder until profile data exists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine.dart';
import '../../core/theme_colors.dart';
import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';
import 'child_chat_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatProvider);
    return chatAsync.when(
      data: (s) => _HomeBody(state: s),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Home error: $e')),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final ChatState state;
  const _HomeBody({required this.state});

  // Most recently advanced skill → a friendly recap line.
  String _recap(MemoryState mem) {
    final tally = gardenTally(mem);
    if (mem.owned.isNotEmpty) {
      return "You got really good at it. Want to keep going, or talk about something new?";
    }
    if (tally.sprouting > 0) {
      return "Your garden is starting to sprout 🌱 Want to keep going, or talk about something new?";
    }
    return "Let's plant your first skill today. What would you like to talk about?";
  }

  String _ctaLabel(MemoryState mem) {
    if (mem.lastTopics.isNotEmpty) {
      return 'Continue: ${mem.lastTopics.first} 💬';
    }
    return 'Start talking with Zoe 💬';
  }

  @override
  Widget build(BuildContext context) {
    final mem = state.memory;
    final bloomed = mem.owned.length;
    final lastTopic = mem.lastTopics.isNotEmpty ? mem.lastTopics.first : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBF9F0), Color(0xFFFFF1E2)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hi there 👋',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "let's keep the garden growing",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Single "skills bloomed" chip (no streak chip).
                  _Chip(
                    bg: EllaColors.limeLightest,
                    fg: EllaColors.limeDark,
                    text: '🌸 $bloomed skill${bloomed == 1 ? '' : 's'} bloomed',
                  ),
                ],
              ),
            ),
            // Body — big Zoe + greeting bubble
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _ZoeBig(),
                    const SizedBox(height: 14),
                    _GreetBubble(
                      lastTopic: lastTopic,
                      recap: _recap(mem),
                    ),
                  ],
                ),
              ),
            ),
            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              child: Column(
                children: [
                  _PrimaryButton(
                    label: _ctaLabel(mem),
                    onTap: () => _openChat(context),
                  ),
                  const SizedBox(height: 9),
                  _GhostButton(
                    label: 'Talk about something else',
                    onTap: () => _openChat(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Container(
          // Reuse the chat screen's sky→grass backdrop (it has a transparent Scaffold).
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF87CEEB), Color(0xFF4CAF50)],
            ),
          ),
          child: const ChildChatScreen(),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final Color bg, fg;
  final String text;
  const _Chip({required this.bg, required this.fg, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _ZoeBig extends StatelessWidget {
  const _ZoeBig();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: EllaColors.zoeMintLight,
        shape: BoxShape.circle,
        border: Border.all(color: EllaColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x2E4CAF82), offset: Offset(0, 8)),
        ],
      ),
      child: const Center(child: Text('🎒', style: TextStyle(fontSize: 46))),
    );
  }
}

class _GreetBubble extends StatelessWidget {
  final String? lastTopic;
  final String recap;
  const _GreetBubble({required this.lastTopic, required this.recap});

  @override
  Widget build(BuildContext context) {
    final callback = lastTopic != null
        ? 'Last time we talked about $lastTopic. '
        : 'Ready for some English today? ';
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: EllaColors.skyLight, width: 1.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x1A3B9EFF), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 17,
            height: 1.5,
            color: EllaColors.skyDeepest,
          ),
          children: [
            TextSpan(text: callback),
            TextSpan(text: recap),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [EllaColors.mangoTop, EllaColors.mangoMain],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(color: EllaColors.mangoDark, offset: Offset(4, 4)),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: EllaColors.surface,
          border: Border.all(color: EllaColors.border, width: 1.5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: EllaColors.secondary,
          ),
        ),
      ),
    );
  }
}
