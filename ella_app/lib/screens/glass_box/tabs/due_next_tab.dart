// Glass Box → Due Next tab
// Shows the current targeting output from the engine:
// active unit step, primary skill, watch list, and
// the full dueSkill / dueUnit picks with their "why" strings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../core/engine.dart';
import '../../../core/skill_data.dart';
import '../../../providers/chat_provider.dart';

class DueNextTab extends ConsumerWidget {
  const DueNextTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(chatProvider).when(
          data: (s) => _DueNextView(state: s),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
  }
}

class _DueNextView extends StatelessWidget {
  final ChatState state;
  const _DueNextView({required this.state});

  @override
  Widget build(BuildContext context) {
    final mem = state.memory;
    final due = mem.dueNext;
    final bar = ownBarFor(mem.level);

    final allPicks = mem.progressionModel == 'units'
        ? dueUnit(mem).picks
        : dueSkill(mem, mem.level);

    final activeU = activeStep(mem);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stored due_next
        _Card('Stored due_next', [
          _row('primary', due.primary ?? '(none)'),
          if (due.primary != null)
            _row('  text', skillText(due.primary!)),
          _row('watching', due.watching.isEmpty ? '(none)' : due.watching.join(', ')),
        ]),

        // Constants in effect
        _Card('Engine constants (${mem.level})', [
          _row('OWN_BAR', '$bar'),
          _row('FLOOR', '$kFloor'),
          _row('SIGHTINGS_TO_OWN', '$kSightingsToOwn'),
          _row('mode', mem.progressionModel),
        ]),

        // Active unit step
        if (mem.progressionModel == 'units')
          _Card('Active unit step', [
            if (activeU == null)
              const Text('All steps complete ✓',
                  style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold))
            else ...[
              _row('step', activeU.step),
              _row('name', activeU.name),
              _row('focus', activeU.focus),
            ],
          ]),

        // Live picks with why strings
        _Card('Current picks (${allPicks.length})', [
          if (allPicks.isEmpty)
            const Text('No picks — all targets met.',
                style: TextStyle(color: Colors.grey))
          else
            for (int i = 0; i < allPicks.length; i++) ...[
              Padding(
                padding: EdgeInsets.only(top: i > 0 ? 10 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: i == 0
                                ? const Color(0xFF4CAF50)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            i == 0 ? 'PRIMARY' : 'WATCH $i',
                            style: TextStyle(
                              fontSize: 10,
                              color: i == 0 ? Colors.white : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(allPicks[i].id,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(skillText(allPicks[i].id),
                        style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    Text(allPicks[i].why,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
        ]),

        // Current session topic
        if (state.currentTopic != null)
          _Card('Current topic', [
            _row('topic', state.currentTopic!.topic),
            _row('theme', state.currentTopic!.theme),
          ]),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                    letterSpacing: 0.8)),
            const Divider(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
