import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/llm_service.dart';
import '../services/tts_manager.dart';

class TtsSettingsSheet extends StatelessWidget {
  const TtsSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ChatProvider>(),
        child: const TtsSettingsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- LLM Provider ---
          Row(
            children: [
              Icon(Icons.psychology, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('LLM Provider',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<LlmProvider>(
            segments: [
              ButtonSegment(
                value: LlmProvider.openai,
                label: const Text('OpenAI'),
                enabled:
                    chat.availableLlmProviders.contains(LlmProvider.openai),
              ),
              ButtonSegment(
                value: LlmProvider.deepseek,
                label: const Text('DeepSeek'),
                enabled:
                    chat.availableLlmProviders.contains(LlmProvider.deepseek),
              ),
            ],
            selected: {chat.llmProvider},
            onSelectionChanged: (v) => chat.setLlmProvider(v.first),
          ),
          const SizedBox(height: 4),
          Text(
            'Model: ${chat.llmModelName}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.outline),
          ),
          const Divider(height: 24),

          // --- STT Engine ---
          Row(
            children: [
              Icon(Icons.mic, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('STT Engine',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<SttEngineType>(
            segments: [
              const ButtonSegment(
                value: SttEngineType.system,
                label: Text('System'),
              ),
              ButtonSegment(
                value: SttEngineType.whisper,
                label: const Text('Whisper'),
                enabled: chat.whisperAvailable,
              ),
            ],
            selected: {chat.sttEngineType},
            onSelectionChanged: (v) => chat.setSttEngine(v.first),
          ),
          if (chat.sttEngineType == SttEngineType.whisper)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Records audio, sends to OpenAI Whisper API',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colorScheme.outline),
              ),
            ),

          const Divider(height: 24),

          // --- TTS Engine ---
          Row(
            children: [
              Icon(Icons.record_voice_over, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('TTS Engine',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<TtsEngineType>(
            segments: [
              ButtonSegment(
                value: TtsEngineType.system,
                label: const Text('System'),
                icon: const Icon(Icons.phone_android, size: 18),
              ),
              ButtonSegment(
                value: TtsEngineType.piper,
                label: const Text('Piper'),
                icon: const Icon(Icons.smart_toy, size: 18),
                enabled: chat.piperAvailable,
              ),
            ],
            selected: {chat.ttsEngineType},
            onSelectionChanged: (v) => chat.setTtsEngine(v.first),
          ),
          if (!chat.piperAvailable) ...[
            const SizedBox(height: 8),
            Text(
              'Piper: loading voice model...',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.outline),
            ),
          ],
          if (chat.piperAvailable &&
              chat.ttsEngineType == TtsEngineType.piper) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Accent / Voice',
                    style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh voice models',
                  onPressed: chat.refreshPiperVoices,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...chat.piperVoices.map(
              (voice) => RadioListTile<String>(
                title: Text(voice.label),
                subtitle:
                    Text(voice.id, style: const TextStyle(fontSize: 12)),
                value: voice.id,
                groupValue: chat.currentPiperVoice?.id,
                onChanged: (_) => chat.setPiperVoice(voice),
                dense: true,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
