import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class VoiceInputBar extends StatelessWidget {
  final TextEditingController textController;
  final VoidCallback onSend;

  const VoiceInputBar({
    super.key,
    required this.textController,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Mic button
            Consumer<ChatProvider>(
              builder: (_, chat, __) => GestureDetector(
                onTap: chat.isLoading ? null : chat.toggleListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: chat.isListening
                        ? colorScheme.error
                        : colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    chat.isListening ? Icons.stop : Icons.mic,
                    color: chat.isListening
                        ? colorScheme.onError
                        : colorScheme.onPrimaryContainer,
                    semanticLabel:
                        chat.isListening ? 'Stop recording' : 'Start recording',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Text field
            Expanded(
              child: TextField(
                controller: textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            Consumer<ChatProvider>(
              builder: (_, chat, __) => IconButton(
                onPressed: chat.isLoading ? null : onSend,
                icon: Icon(
                  Icons.send_rounded,
                  color: chat.isLoading
                      ? colorScheme.outline
                      : colorScheme.primary,
                ),
                tooltip: 'Send message',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
