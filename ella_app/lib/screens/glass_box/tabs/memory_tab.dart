// Glass Box → Memory tab
// Ports the simulator's MemoryView: state-changes banner, full memory object
// as formatted JSON (mono block), and per-chat snapshots underneath.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/memory_snapshot.dart';
import '../../../providers/chat_provider.dart';

class MemoryTab extends ConsumerWidget {
  const MemoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(chatProvider)
        .when(
          data: (s) => _MemoryView(state: s),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
  }
}

class _MemoryView extends StatelessWidget {
  final ChatState state;
  const _MemoryView({required this.state});

  String _formattedMemory() {
    final m = state.memory;
    // Build the object in the same shape as the simulator's display.
    final obj = {
      'profile': {'child_id': m.childId},
      'level': m.level,
      'progression_model': m.progressionModel,
      'owned [${m.owned.length}]': m.owned,
      'emerging [${m.emerging.length}]': m.emerging,
      'due_next': {
        'primary': m.dueNext.primary,
        'watching': m.dueNext.watching,
      },
      'last_topics': m.lastTopics,
      'interests': m.interests,
      'effort': {'times_spoken_total': m.effortTimesSpoken},
      'sightings': m.sightings,
      'strength': m.strength,
      'last_seen': m.lastSeen,
      'chat_count': m.chatCount,
      'updated_after_chat': m.updatedAfterChat,
    };
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(obj);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Supabase sync error banner — only shown when something failed.
        if (state.lastSyncError != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFBE9E7),
              border: Border.all(color: const Color(0xFFB8472F), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️ ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    state.lastSyncError!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFB8472F),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // State changes this chat
        if (state.lastChanges.isNotEmpty) ...[
          const Text(
            'state changes this chat',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB8472F),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          for (final c in state.lastChanges)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F3E9),
                border: Border.all(color: const Color(0xFF3AA655)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${c.id} · ${c.from} → ${c.to} ${c.to == 'owned' ? '🌳' : '🌱'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],

        // Memory object header
        Text(
          state.memory.updatedAfterChat > 0
              ? 'memory object · updated after chat ${state.memory.updatedAfterChat}'
              : 'memory object · (fresh)',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB8472F),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),

        // Memory as JSON block (dark mono, like the simulator)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1B16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            _formattedMemory(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.55,
              color: Color(0xFFEFE9D8),
            ),
          ),
        ),

        // Snapshots after each chat
        if (state.snapshots.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'memory after each chat',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB8472F),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          for (final s in state.snapshots) _SnapshotRow(snapshot: s),
        ],

        const SizedBox(height: 8),
        const Text(
          'owned/emerging hold buckets; confidence is NOT stored here (see Session tab). '
          'Snapshots show how memory evolved chat by chat.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  final MemorySnapshot snapshot;
  const _SnapshotRow({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'after chat ${snapshot.chat} (${snapshot.model}) · '
            'owned ${snapshot.owned.length} · emerging ${snapshot.emerging.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            'due → ${snapshot.dueFlat.isEmpty ? '(none)' : snapshot.dueFlat.join(', ')}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Color(0xFF5B50C4),
            ),
          ),
          const Divider(height: 8),
        ],
      ),
    );
  }
}
