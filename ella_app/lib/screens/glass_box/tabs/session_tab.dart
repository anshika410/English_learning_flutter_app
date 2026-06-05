// Glass Box → Session tab
// Accordion of immutable per-chat session records.
// Memory overwrites; these accumulate.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../providers/chat_provider.dart';

class SessionTab extends ConsumerWidget {
  const SessionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(chatProvider).when(
          data: (s) => _SessionView(logs: s.sessionLogs),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
  }
}

class _SessionView extends StatelessWidget {
  final List<SessionLog> logs;
  const _SessionView({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No session logs yet.\nEach completed chat writes one immutable record here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'session logs — immutable, one per chat (${logs.length})',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
                letterSpacing: 0.8),
          ),
        ),
        for (int i = 0; i < logs.length; i++) _SessionTile(log: logs[i], index: i),
        const SizedBox(height: 8),
        const Text(
          'Accumulates (memory overwrites; these do not).',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _SessionTile extends StatefulWidget {
  final SessionLog log;
  final int index;
  const _SessionTile({required this.log, required this.index});

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _open = false;

  String get _summary {
    final l = widget.log;
    return 'chat #${l.chatNumber} · ${l.turnsTotal} turns · '
        '${l.judgeScoresRaw.length} scored · ${l.stateChanges.length} changes';
  }

  String get _pretty {
    // Schema-shaped JSON (what's in Supabase) PLUS the in-memory transcript.
    final j = widget.log.toJson();
    final full = {
      ...j,
      'transcript': widget.log.transcript,
    };
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(full);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F0F9),
        border: Border.all(color: Colors.black87, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_summary,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1F1B16),
              child: SelectableText(
                _pretty,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    height: 1.4,
                    color: Color(0xFFEFE9D8)),
              ),
            ),
        ],
      ),
    );
  }
}
