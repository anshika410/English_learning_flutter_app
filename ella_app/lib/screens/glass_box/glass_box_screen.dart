// Glass Box screen — teacher/developer view of the engine internals.
// Eleven tabs, level selector in the app bar.
// Gated behind kShowGlassBox in app.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
import 'tabs/dual_judge_tab.dart';
import 'tabs/due_next_tab.dart';
import 'tabs/edit_prompts_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/judge_tab.dart';
import 'tabs/llm_info_tab.dart';
import 'tabs/memory_tab.dart';
import 'tabs/prompt_tab.dart';
import 'tabs/readme_tab.dart';
import 'tabs/session_tab.dart';
import 'tabs/skills_tab.dart';

const List<String> _kLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

class GlassBoxScreen extends ConsumerStatefulWidget {
  const GlassBoxScreen({super.key});

  @override
  ConsumerState<GlassBoxScreen> createState() => _GlassBoxScreenState();
}

class _GlassBoxScreenState extends ConsumerState<GlassBoxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 11, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _confirmLevelChange(String level) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Switch level to $level?'),
        content: const Text(
          'Wipes in-memory state and starts a fresh chat at the new level. '
          'Supabase row is not touched until next End Chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm == true) {
      final messenger = ScaffoldMessenger.of(context);
      ref.read(chatProvider.notifier).setLevel(level).catchError((e) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = ref
        .watch(chatProvider)
        .maybeWhen(data: (s) => s.memory.level, orElse: () => 'A1');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          '🔬 Glass Box',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: DropdownButton<String>(
                value: currentLevel,
                underline: const SizedBox.shrink(),
                items: _kLevels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (l) {
                  if (l != null && l != currentLevel) {
                    _confirmLevelChange(l);
                  }
                },
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4CAF50),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: '📖 Read me'),
            Tab(text: '🧠 Memory'),
            Tab(text: '⚖️ Judge'),
            Tab(text: '⚖️⚖️ Both'),
            Tab(text: '📜 Session'),
            Tab(text: '🎯 due_next'),
            Tab(text: '📝 Prompt'),
            Tab(text: '✏️ Prompts'),
            Tab(text: '🌱 Skills'),
            Tab(text: '📊 History'),
            Tab(text: '⚙️ LLM'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          ReadMeTab(),
          MemoryTab(),
          JudgeTab(),
          DualJudgeTab(),
          SessionTab(),
          DueNextTab(),
          PromptTab(),
          EditPromptsTab(),
          SkillsTab(),
          HistoryTab(),
          LlmInfoTab(),
        ],
      ),
    );
  }
}
