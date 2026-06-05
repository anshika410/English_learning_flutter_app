// Glass Box → Both tab
// Same transcript scored under BOTH framings side-by-side.
// On narrow screens, stacks vertically.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/child_memory.dart';
import '../../../providers/chat_provider.dart';
import 'judge_tab.dart';

class DualJudgeTab extends ConsumerWidget {
  const DualJudgeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(chatProvider).when(
          data: (s) => _DualView(
            primaryLabel: s.memory.progressionModel,
            primary: s.lastJudgeScores,
            otherLabel: s.lastJudgeOtherLabel,
            other: s.lastJudgeScoresOther,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
  }
}

class _DualView extends StatelessWidget {
  final String primaryLabel;
  final List<SkillScore> primary;
  final String otherLabel;
  final List<SkillScore> other;

  const _DualView({
    required this.primaryLabel,
    required this.primary,
    required this.otherLabel,
    required this.other,
  });

  @override
  Widget build(BuildContext context) {
    if (primary.isEmpty && other.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No comparison yet.\n\nEnd a chat — the same transcript is judged under '
            'BOTH framings and shown side by side.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF0D9),
            border: Border.all(color: const Color(0xFFC8861A), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Same transcript, judged two ways. The conversation was steered by the '
            '"$primaryLabel" model; this shows how each framing would score it.',
            style: const TextStyle(fontSize: 11, color: Color(0xFF7A5A13)),
          ),
        ),
        // Two side-by-side columns on wide screens, stacked on narrow.
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth > 700) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Column(label: primaryLabel, scores: primary)),
                const SizedBox(width: 8),
                Expanded(child: _Column(label: otherLabel, scores: other)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Column(label: primaryLabel, scores: primary),
              const SizedBox(height: 16),
              _Column(label: otherLabel, scores: other),
            ],
          );
        }),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  final String label;
  final List<SkillScore> scores;
  const _Column({required this.label, required this.scores});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label framing',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
                letterSpacing: 0.8)),
        const SizedBox(height: 6),
        if (scores.isEmpty)
          const Text('(no scores)',
              style: TextStyle(color: Colors.grey, fontSize: 12))
        else
          for (final s in scores) ScoreCard(score: s),
      ],
    );
  }
}
