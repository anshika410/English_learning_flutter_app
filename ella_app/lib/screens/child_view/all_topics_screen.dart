// "See More" topics screen — the full list from GET /users/me/topics. Tapping a
// card starts a session on that topic via the same path as the home chips
// (startTopicSession → POST /session).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/home_topic.dart';
import '../../providers/topics_provider.dart';
import 'topic_launcher.dart';
import 'widgets/garden_sky_background.dart';

class AllTopicsScreen extends ConsumerWidget {
  final VoidCallback? onConversationEnded;

  const AllTopicsScreen({super.key, this.onConversationEnded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider);
    return GardenSkyBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: EllaColors.ink,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  Text('Pick a topic', style: EllaTextStyles.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: topicsAsync.when(
                  data: (topics) => topics.isEmpty
                      ? const _Message(text: 'No topics to show yet.')
                      : ListView.separated(
                          itemCount: topics.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _TopicCard(
                            topic: topics[i],
                            onTap: () => startTopicSession(
                              context,
                              ref,
                              topics[i],
                              onConversationEnded: onConversationEnded,
                            ),
                          ),
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      _Message(text: 'Could not load topics.\n$e'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final HomeTopic topic;
  final VoidCallback onTap;

  const _TopicCard({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fill = parseCssColor(topic.color) ?? EllaColors.surface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: EllaColors.ink.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (topic.icon.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 2),
                child: Text(
                  topic.icon,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.name,
                    style: EllaTextStyles.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (topic.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      topic.description,
                      style: EllaTextStyles.bodySmall.copyWith(
                        color: EllaColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message({required this.text});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: EllaTextStyles.bodyBase.copyWith(color: EllaColors.textSecondary),
    ),
  );
}
