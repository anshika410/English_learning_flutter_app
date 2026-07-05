// Glass Box → Edit Prompts tab
// Live-editable AppPrompts. Writes to promptsOverrideProvider; ChatNotifier
// reads from that provider when building prompts. Reset restores defaults.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/prompts.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/prompts_provider.dart';

class EditPromptsTab extends ConsumerStatefulWidget {
  const EditPromptsTab({super.key});

  @override
  ConsumerState<EditPromptsTab> createState() => _EditPromptsTabState();
}

class _EditPromptsTabState extends ConsumerState<EditPromptsTab> {
  late final Map<String, TextEditingController> _ctls;

  @override
  void initState() {
    super.initState();
    final p = ref.read(promptsOverrideProvider);
    _ctls = {
      'base': TextEditingController(text: p.base),
      'profileA1': TextEditingController(text: p.profileA1),
      'profileB1': TextEditingController(text: p.profileB1),
      'convSkill': TextEditingController(text: p.convSkill),
      'convUnit': TextEditingController(text: p.convUnit),
      'judge': TextEditingController(text: p.judge),
    };
  }

  @override
  void dispose() {
    for (final c in _ctls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    final p = AppPrompts(
      base: _ctls['base']!.text,
      profileA1: _ctls['profileA1']!.text,
      profileB1: _ctls['profileB1']!.text,
      convSkill: _ctls['convSkill']!.text,
      convUnit: _ctls['convUnit']!.text,
      judge: _ctls['judge']!.text,
    );
    ref.read(promptsOverrideProvider.notifier).state = p;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompts applied. Next chat uses them.')),
    );
  }

  void _resetDefaults() {
    setState(() {
      _ctls['base']!.text = kDefaultPrompts.base;
      _ctls['profileA1']!.text = kDefaultPrompts.profileA1;
      _ctls['profileB1']!.text = kDefaultPrompts.profileB1;
      _ctls['convSkill']!.text = kDefaultPrompts.convSkill;
      _ctls['convUnit']!.text = kDefaultPrompts.convUnit;
      _ctls['judge']!.text = kDefaultPrompts.judge;
    });
    ref.read(promptsOverrideProvider.notifier).state = kDefaultPrompts;
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref
        .watch(chatProvider)
        .maybeWhen(
          data: (s) => s.memory.progressionModel,
          orElse: () => 'units',
        );

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
          child: const Text(
            'Edit any prompt, hit Apply, then start a new chat to see the effect. '
            '{{TARGETS}}, {{UNITNAME}}, {{UNITFOCUS}} are filled automatically.',
            style: TextStyle(fontSize: 11, color: Color(0xFF7A5A13)),
          ),
        ),
        _field('Base prompt (shared)', 'base'),
        _field('Profile · A1 / A2', 'profileA1'),
        _field('Profile · B1+', 'profileB1'),
        _field(
          'Conversation framing · ${mode == 'units' ? 'UNITS (theme-led)' : 'MICRO-SKILL (list-led)'}',
          mode == 'units' ? 'convUnit' : 'convSkill',
        ),
        _field('Judge prompt (shared)', 'judge'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _resetDefaults,
              child: const Text('↺ Reset to defaults'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB8472F),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _ctls[key],
            maxLines: 8,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.4,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black87),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }
}
