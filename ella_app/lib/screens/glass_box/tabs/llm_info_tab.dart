// Glass Box → LLM tab
// Static info panel for the Flutter app.
// Unlike the simulator's runtime/direct/proxy switcher, the Android app uses
// the Supabase Edge Function llm-proxy only. Changing providers is an env change.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/chat_provider.dart';

class LlmInfoTab extends ConsumerWidget {
  const LlmInfoTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chatProvider);
    final live = async.maybeWhen(
        data: (s) => s.liveLlmLastCall, orElse: () => true);
    final notifier = ref.read(chatProvider.notifier);
    final proxy = dotenv.env['LLM_PROXY_URL'] ?? '(not set)';
    final authUid =
        Supabase.instance.client.auth.currentUser?.id ?? '(not signed in)';
    final restoredCount = async.maybeWhen(
        data: (s) => s.sessionLogs.length, orElse: () => 0);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Identity — useful for confirming the anon session persists across
        // app restarts (same auth.uid before/after relaunch = restore works).
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F0F9),
            border: Border.all(color: const Color(0xFF2F6FB0), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('IDENTITY',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F6FB0),
                      letterSpacing: 0.8)),
              const SizedBox(height: 4),
              _idRow('auth.uid', authUid),
              _idRow('child_id', notifier.childId),
              _idRow('online', notifier.online ? 'yes' : 'no (offline mode)'),
              _idRow(
                  'restored',
                  restoredCount == 0
                      ? '0 prior chats from Supabase'
                      : '$restoredCount prior chats from Supabase'),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF0D9),
            border: Border.all(color: const Color(0xFFC8861A), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'On Android we route LLM calls through the Supabase Edge Function. '
            'Keys live server-side. To switch providers, edit the edge function env.',
            style: TextStyle(fontSize: 11, color: Color(0xFF7A5A13)),
          ),
        ),
        _section('Mode', 'proxy (Supabase Edge Function)'),
        _section('Provider', 'DeepSeek'),
        _section('Conv model', 'deepseek-chat'),
        _section('Judge model', 'deepseek-chat'),
        _section('Proxy URL', proxy),
        _section('Last call', live ? 'live' : 'mock / fallback'),
        const SizedBox(height: 12),
        const Text(
          'The simulator\'s ⚙️ LLM tab supports switching providers from the '
          'browser — that\'s a debugging tool that doesn\'t apply to the production '
          'app. Switching providers here means updating DEEPSEEK_API_KEY (or '
          'pointing the proxy at a different vendor) in the edge function\'s env.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _idRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2F6FB0),
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Color(0xFF1F1B16),
                )),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
