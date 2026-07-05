// "See More" topics screen — the full set of suggested topics from the memory
// API's next_topics (recommended + alternatives). Tapping a card selects that
// topic and returns it (via Navigator.pop) to the home screen; it does not start
// a session. The card shows the short `label`; the home CTA then sends the
// topic `name` to POST /session.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';
import '../../services/audio_service.dart';
import 'widgets/garden_sky_background.dart';
import 'widgets/zoe_mascot.dart';

class AllTopicsScreen extends ConsumerWidget {
  const AllTopicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(chatProvider).asData?.value.memory;
    final topics = _topicsFrom(memory);

    // Scaffold gives a Material ancestor so Text renders without the debug
    // yellow underline (this screen is pushed as a bare route).
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GardenSkyBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircleBackButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 12),
              const _MascotPrompt(text: 'Choose any topic that you like'),
              const SizedBox(height: 16),
              Expanded(
                child: topics.isEmpty
                    ? Center(
                        child: Text(
                          'No topics to show yet.',
                          style: EllaTextStyles.bodyBase.copyWith(
                            color: EllaColors.textSecondary,
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.92,
                        ),
                        itemCount: topics.length,
                        itemBuilder: (_, i) => _TopicCard(
                          topic: topics[i],
                          onTap: () {
                            playTapClick();
                            Navigator.of(context).pop(topics[i]);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // Recommended first, then alternatives, de-duplicated by name.
  static List<TopicChoice> _topicsFrom(MemoryState? memory) {
    if (memory == null) return const [];
    final next = memory.nextTopics;
    final out = <TopicChoice>[];
    final seen = <String>{};
    for (final t in [
      if (next.recommended != null) next.recommended!,
      ...next.alternatives,
    ]) {
      if (t.name.isNotEmpty && seen.add(t.name)) out.add(t);
    }
    return out;
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        playTapClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: EllaColors.surface,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 22,
          color: EllaColors.ink,
        ),
      ),
    );
  }
}

class _MascotPrompt extends StatelessWidget {
  final String text;
  const _MascotPrompt({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ZoeMascot(
          mode: ZoeMascotMode.listening,
          size: 72,
          reducedMotion: MediaQuery.of(context).disableAnimations,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: EllaColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: EllaColors.info, width: 2),
            ),
            child: Text(text, style: EllaTextStyles.bodySemibold),
          ),
        ),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  final TopicChoice topic;
  final VoidCallback onTap;

  const _TopicCard({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: EllaColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: EllaColors.ink.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_rounded,
              size: 26,
              color: EllaColors.ink,
            ),
            const SizedBox(height: 8),
            Text(
              topic.display,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: EllaTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
