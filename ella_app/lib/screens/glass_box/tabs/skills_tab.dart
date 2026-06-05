// Glass Box → Skills tab
// Shows every skill at the current level, colour-coded by bucket.
// Also shows unit step skills separately.
// Owned = green, Emerging = amber, Locked = grey.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/engine.dart';
import '../../../core/skill_data.dart';
import '../../../models/child_memory.dart';
import '../../../providers/chat_provider.dart';

class SkillsTab extends ConsumerWidget {
  const SkillsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(chatProvider).when(
          data: (s) => _SkillsView(mem: s.memory),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
  }
}

class _SkillsView extends StatelessWidget {
  final MemoryState mem;
  const _SkillsView({required this.mem});

  @override
  Widget build(BuildContext context) {
    final levelSkills = skillsAtLevel(mem.level);
    final byStrand = <String, List<SkillDef>>{};
    for (final s in levelSkills) {
      byStrand.putIfAbsent(s.strand, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Level summary chips
        _LevelSummary(mem: mem, total: levelSkills.length),
        const SizedBox(height: 12),

        // Flat skills by strand
        for (final strand in ['VOC', 'GRA', 'FLU'])
          if (byStrand[strand] != null)
            _StrandCard(
              strand: strand,
              skills: byStrand[strand]!,
              mem: mem,
            ),

        // Unit steps
        const SizedBox(height: 8),
        const Text('UNIT STEPS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        for (final u in kUnitSteps)
          _UnitStepCard(unit: u, mem: mem),
      ],
    );
  }
}

class _LevelSummary extends StatelessWidget {
  final MemoryState mem;
  final int total;
  const _LevelSummary({required this.mem, required this.total});

  @override
  Widget build(BuildContext context) {
    final ownedCount = mem.owned
        .where((id) => kFlatSkillsById[id]?.level == mem.level)
        .length;
    final emergingCount = mem.emerging
        .where((id) => kFlatSkillsById[id]?.level == mem.level)
        .length;
    final lockedCount = total - ownedCount - emergingCount;

    return Row(
      children: [
        _Chip('$ownedCount owned', const Color(0xFF4CAF50)),
        const SizedBox(width: 8),
        _Chip('$emergingCount emerging', Colors.amber),
        const SizedBox(width: 8),
        _Chip('$lockedCount locked', Colors.grey),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _StrandCard extends StatelessWidget {
  final String strand;
  final List<SkillDef> skills;
  final MemoryState mem;

  const _StrandCard(
      {required this.strand, required this.skills, required this.mem});

  @override
  Widget build(BuildContext context) {
    final label = switch (strand) {
      'VOC' => 'Vocabulary',
      'GRA' => 'Grammar',
      _ => 'Fluency',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                    letterSpacing: 0.8)),
            const Divider(height: 10),
            for (final s in skills) _SkillRow(skill: s, mem: mem),
          ],
        ),
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final SkillDef skill;
  final MemoryState mem;
  const _SkillRow({required this.skill, required this.mem});

  @override
  Widget build(BuildContext context) {
    final bucket = bucketOf(mem, skill.id);
    final color = switch (bucket) {
      'owned' => const Color(0xFF4CAF50),
      'emerging' => Colors.amber,
      _ => Colors.grey,
    };
    final sightings = mem.sightings[skill.id] ?? 0;
    final strength = mem.strength[skill.id] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(skill.text,
                style: TextStyle(
                    fontSize: 13,
                    color: bucket == 'locked'
                        ? Colors.grey.shade500
                        : Colors.black87)),
          ),
          if (sightings > 0 || strength > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                's:$sightings e:$strength',
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnitStepCard extends StatelessWidget {
  final UnitStep unit;
  final MemoryState mem;
  const _UnitStepCard({required this.unit, required this.mem});

  @override
  Widget build(BuildContext context) {
    final complete = unitComplete(mem, unit);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: complete ? const Color(0xFFE8F5E9) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Step ${unit.step}: ${unit.name}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50)),
                ),
                const Spacer(),
                if (complete)
                  const Text('✓ done',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 8),
            for (final s in unit.skills)
              _UnitSkillRow(skill: s, mem: mem),
          ],
        ),
      ),
    );
  }
}

class _UnitSkillRow extends StatelessWidget {
  final UnitSkillRef skill;
  final MemoryState mem;
  const _UnitSkillRow({required this.skill, required this.mem});

  @override
  Widget build(BuildContext context) {
    final bucket = bucketOf(mem, skill.id);
    final color = switch (bucket) {
      'owned' => const Color(0xFF4CAF50),
      'emerging' => Colors.amber,
      _ => Colors.grey,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text('[${skill.strand}] ',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          Expanded(
            child: Text(skill.text,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
