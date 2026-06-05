// Glass Box → History tab
// One compact row per completed chat: aimed N / hit M, owned X, +C grew.
// The big transcript dump lives in the Session tab now.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/history_entry.dart';
import '../../../providers/chat_provider.dart';

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(chatProvider).when(
          data: (s) => _HistoryView(entries: s.historyEntries),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
  }
}

class _HistoryView extends StatelessWidget {
  final List<HistoryEntry> entries;
  const _HistoryView({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No chats completed yet.',
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
            'session history — the loop evolving',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
                letterSpacing: 0.8),
          ),
        ),
        for (final h in entries) _EntryRow(entry: h),
        const SizedBox(height: 8),
        const Text(
          '"aimed/hit" = did due_next steering work — how many targets actually showed up.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  final HistoryEntry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'chat ${entry.chat} (${entry.model}/${entry.level})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            'owned ${entry.owned} · +${entry.changes} grew · '
            'aimed ${entry.aimed}/hit ${entry.hit} · ${entry.turns} turns',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }
}
