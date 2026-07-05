// Glass Box → Judge tab
// Raw scores from the last endChat (PRIMARY framing).
// Mirrors the simulator's JudgeView: id · confidence bar · evidence quote.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/skill_data.dart';
import '../../../models/child_memory.dart';
import '../../../providers/chat_provider.dart';

class JudgeTab extends ConsumerWidget {
  const JudgeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(chatProvider)
        .when(
          data: (s) => _JudgeView(scores: s.lastJudgeScores),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
  }
}

class _JudgeView extends StatelessWidget {
  final List<SkillScore> scores;
  const _JudgeView({required this.scores});

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No judge run yet.\nHave a short chat, then End chat & judge.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'skills_evidenced[] — primary framing',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
              letterSpacing: 0.8,
            ),
          ),
        ),
        for (final s in scores) ScoreCard(score: s),
        const SizedBox(height: 8),
        const Text(
          '≥0.70 promotes emerging→owned (level-scaled) · ≥0.30 starts locked→emerging · <0.30 ignored.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class ScoreCard extends StatelessWidget {
  final SkillScore score;
  const ScoreCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final c = score.confidence;
    final color = c >= 0.7
        ? const Color(0xFF23682F)
        : c >= 0.3
        ? const Color(0xFFC8861A)
        : const Color(0xFFB8472F);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  score.id,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                c.toStringAsFixed(2),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            score.prompted ? 'prompted' : 'unprompted',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            skillText(score.id),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: c.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (score.evidence.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"${score.evidence}"',
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
