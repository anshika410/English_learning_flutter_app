// "See More" topics screen — the full set of suggested topics from the memory
// API's next_topics (recommended + alternatives). Tapping a card selects that
// topic and returns it (via Navigator.pop) to the home screen; it does not start
// a session. The card shows the short `label`; the home CTA then sends the
// topic `name` to POST /session.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ella_smooth_shape.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/child_memory.dart';
import '../../providers/chat_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/audio_service.dart';
import '../../services/sounds.dart';
import 'widgets/home_scene_background.dart';
import 'widgets/topic_icon.dart';
import 'widgets/zoe_mascot.dart';

class AllTopicsScreen extends ConsumerWidget {
  final List<String> excludeTopicNames;

  const AllTopicsScreen({super.key, this.excludeTopicNames = const []});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = ref.watch(chatProvider).asData?.value.memory;
    final topics = _topicsFrom(memory);

    // Scaffold gives a Material ancestor so Text renders without the debug
    // yellow underline (this screen is pushed as a bare route).
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HomeSceneBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CircleBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 12),
                const _MascotPrompt(text: 'Choose any topic that you like'),
                const SizedBox(height: 18),
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
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            const columnCount = 3;
                            const horizontalGap = 8.0;
                            final cardWidth =
                                (constraints.maxWidth -
                                    horizontalGap * (columnCount - 1)) /
                                columnCount;
                            final rowCount =
                                (topics.length + columnCount - 1) ~/
                                columnCount;

                            return ListView.separated(
                              key: const ValueKey('all-topics-list'),
                              padding: const EdgeInsets.only(bottom: 4),
                              itemCount: rowCount,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, rowIndex) {
                                final start = rowIndex * columnCount;
                                final end = (start + columnCount).clamp(
                                  0,
                                  topics.length,
                                );
                                final rowTopics = topics.sublist(start, end);
                                final horizontalPadding =
                                    responsiveTopicHorizontalPadding(
                                      context,
                                      labels: rowTopics.map(
                                        (topic) => topic.display,
                                      ),
                                      cardWidth: cardWidth,
                                    );
                                final labelWidth =
                                    cardWidth - horizontalPadding * 2;
                                final layouts = [
                                  for (final topic in rowTopics)
                                    measureTopicLabel(
                                      context,
                                      text: topic.display,
                                      maxWidth: labelWidth,
                                    ),
                                ];
                                var rowLabelHeight = 0.0;
                                for (final layout in layouts) {
                                  if (layout.height > rowLabelHeight) {
                                    rowLabelHeight = layout.height;
                                  }
                                }
                                final rowHeight =
                                    kTopicCardVerticalPadding * 2 +
                                    kTopicIconSize +
                                    kTopicIconLabelGap +
                                    rowLabelHeight;

                                return SizedBox(
                                  key: ValueKey('all-topics-row-$rowIndex'),
                                  height: rowHeight,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (
                                        var columnIndex = 0;
                                        columnIndex < columnCount;
                                        columnIndex++
                                      ) ...[
                                        if (columnIndex > 0)
                                          const SizedBox(width: horizontalGap),
                                        Expanded(
                                          child: columnIndex < rowTopics.length
                                              ? _TopicCard(
                                                  topic: rowTopics[columnIndex],
                                                  labelLayout:
                                                      layouts[columnIndex],
                                                  labelSlotHeight:
                                                      rowLabelHeight,
                                                  horizontalPadding:
                                                      horizontalPadding,
                                                  onTap: () {
                                                    ref
                                                        .read(audioProvider)
                                                        .playSfx(Sounds.topic);
                                                    Navigator.of(context).pop(
                                                      rowTopics[columnIndex],
                                                    );
                                                  },
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            );
                          },
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
  List<TopicChoice> _topicsFrom(MemoryState? memory) {
    if (memory == null) return const [];
    final next = memory.nextTopics;
    final out = <TopicChoice>[];
    final seen = <String>{};
    for (final t in [
      if (next.recommended != null) next.recommended!,
      ...next.alternatives,
    ]) {
      if (t.name.isNotEmpty && seen.add(t.name)) {
        if (!excludeTopicNames.contains(t.name)) {
          out.add(t);
        }
      }
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
        decoration: const ShapeDecoration(
          color: EllaColors.surface,
          shadows: [
            BoxShadow(
              color: EllaColors.greenDeep,
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
          shape: CircleBorder(
            side: BorderSide(color: EllaColors.greenDeep, width: 2),
          ),
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
            decoration: ellaSmoothDecoration(
              color: EllaColors.surface,
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: EllaColors.info, width: 2),
              shadows: const [
                BoxShadow(
                  color: EllaColors.infoDark,
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
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
  final TopicLabelLayout labelLayout;
  final double labelSlotHeight;
  final double horizontalPadding;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.labelLayout,
    required this.labelSlotHeight,
    required this.horizontalPadding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        key: ValueKey('all-topics-card-${topic.name}'),
        // The smooth 1.5px outline supplies the remainder of each effective
        // inset, keeping the artwork aligned with home chips.
        padding: EdgeInsets.fromLTRB(
          horizontalPadding - 1.5,
          kTopicCardVerticalPadding - 1.5,
          horizontalPadding - 1.5,
          kTopicCardVerticalPadding - 1.5,
        ),
        alignment: Alignment.topCenter,
        decoration: ellaSmoothDecoration(
          color: EllaColors.surface,
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: EllaColors.ink.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TopicIcon(
              key: ValueKey('all-topics-icon-${topic.name}'),
              icon: topic.icon,
              size: kTopicIconSize,
              fallbackColor: EllaColors.ink,
            ),
            const SizedBox(height: kTopicIconLabelGap),
            TopicCardLabel(
              key: ValueKey('all-topics-label-${topic.name}'),
              text: topic.display,
              color: Colors.black,
              layout: labelLayout,
              slotHeight: labelSlotHeight,
            ),
          ],
        ),
      ),
    );
  }
}
