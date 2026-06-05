// Glass Box → Prompt tab
// Shows the full assembled Zoe prompt (buildConvPrompt) and the judge prompt
// (buildJudgePrompt) that would be sent to the LLM right now.
// Useful for iterating on prompt content without deploying.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/engine.dart';
import '../../../core/prompts.dart';
import '../../../core/skill_data.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/prompts_provider.dart';

class PromptTab extends ConsumerStatefulWidget {
  const PromptTab({super.key});

  @override
  ConsumerState<PromptTab> createState() => _PromptTabState();
}

class _PromptTabState extends ConsumerState<PromptTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [Tab(text: 'Conv prompt'), Tab(text: 'Judge prompt')],
        ),
        Expanded(
          child: ref.watch(chatProvider).when(
                data: (s) {
                  final prompts = ref.watch(promptsOverrideProvider);
                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _PromptView(
                        label: 'Zoe conv prompt',
                        text: buildConvPrompt(
                          mem: s.memory,
                          progressionModel: s.memory.progressionModel,
                          level: s.memory.level,
                          history: s.convHistory,
                          prompts: prompts,
                          currentTopic: s.currentTopic,
                        ),
                      ),
                      _PromptView(
                        label: 'Judge prompt',
                        text: _judgePrompt(s, prompts),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
        ),
      ],
    );
  }

  String _judgePrompt(ChatState s, AppPrompts prompts) {
    final mem = s.memory;
    final skillIds = mem.dueNext.flat.isNotEmpty
        ? mem.dueNext.flat
        : [kFlatSkills.firstWhere((sk) => sk.level == mem.level).id];
    return buildJudgePrompt(
      level: mem.level,
      skillIds: skillIds,
      history: s.convHistory,
      prompts: prompts,
    );
  }
}

class _PromptView extends StatelessWidget {
  final String label;
  final String text;
  const _PromptView({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18),
                tooltip: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: SelectableText(
              text,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
