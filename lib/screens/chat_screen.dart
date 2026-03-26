import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_input_bar.dart';
import '../widgets/tts_settings_sheet.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().initialize();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    context.read<ChatProvider>().sendMessage(text);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ella'),
        actions: [
          Consumer<ChatProvider>(
            builder: (_, chat, __) => IconButton(
              icon: Icon(
                chat.autoSpeak ? Icons.volume_up : Icons.volume_off,
              ),
              tooltip: chat.autoSpeak ? 'Auto-speak on' : 'Auto-speak off',
              onPressed: chat.toggleAutoSpeak,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            tooltip: 'Voice settings',
            onPressed: () => TtsSettingsSheet.show(context),
          ),
          Consumer<ChatProvider>(
            builder: (_, chat, __) => IconButton(
              icon: Icon(
                chat.showLatency ? Icons.timer : Icons.timer_off_outlined,
              ),
              tooltip: chat.showLatency ? 'Hide latency' : 'Show latency',
              onPressed: chat.toggleShowLatency,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (_, chat, __) {
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == chat.messages.length) {
                      return const _TypingIndicator();
                    }
                    return ChatBubble(
                      message: chat.messages[index],
                      showLatency: chat.showLatency,
                      onSpeak: () =>
                          chat.speakMessage(chat.messages[index].content),
                    );
                  },
                );
              },
            ),
          ),
          // Live transcript
          Consumer<ChatProvider>(
            builder: (_, chat, __) {
              if (!chat.isListening) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chat.currentTranscript.isEmpty
                            ? 'Listening...'
                            : chat.currentTranscript,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Input bar
          VoiceInputBar(
            textController: _textController,
            onSend: _handleSend,
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Ella is thinking...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
