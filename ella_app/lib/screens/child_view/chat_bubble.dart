import 'package:flutter/material.dart';

import '../../core/ella_smooth_shape.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';

class ChatBubble extends StatelessWidget {
/// Strip markdown syntax for plain text (used for TTS).
String stripMarkdown(String text) {
  return text
      .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
      .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
      .replaceAll(RegExp(r'__(.+?)__'), r'$1')
      .replaceAll(RegExp(r'_(.+?)_'), r'$1')
      .replaceAll(RegExp(r'`(.+?)`'), r'$1')
      .replaceAll(RegExp(r'~~(.+?)~~'), r'$1')
      .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1')
      .replaceAll(RegExp(r'^#+\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '')
      .trim();
}

class ChatBubble extends ConsumerWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isZoe = message.sender == MessageSender.zoe;

    int highlightStart = -1;
    int highlightEnd = -1;

    if (isZoe) {
      final chatState = ref.watch(chatProvider).value;
      if (chatState != null && chatState.currentlySpeakingMessageId == message.id) {
        highlightStart = chatState.highlightStart;
        highlightEnd = chatState.highlightEnd;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: isZoe ? 12 : 56,
        right: isZoe ? 56 : 12,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment: isZoe
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isZoe) ...[_ZoeAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: isZoe
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: EllaColors.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TypewriterText(
                    key: ValueKey(message.id),
                    text: message.text,
                    highlightStart: highlightStart,
                    highlightEnd: highlightEnd,
                  ),
                )
              : DottedBorder(
                  color: const Color(0xFFE91E63),
                  strokeWidth: 2.5,
                  dashPattern: const [8, 4],
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(18),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SpokenTextFlow(
                      text: message.text,
                      style: EllaTextStyles.bodyBase.copyWith(
                        color: const Color(0xFF880E4F),
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _ZoeAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: EllaColors.greenDark,
        shape: BoxShape.circle,
      ),
      child: const Center(child: Text('🎒', style: TextStyle(fontSize: 16))),
    );
  }
}

// Shown while Zoe is thinking
class ThinkingBubble extends StatefulWidget {
  const ThinkingBubble({super.key});

  @override
  State<ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      child: Row(
        children: [
          _ZoeAvatar(),
          const SizedBox(width: 8),
          FadeTransition(
            opacity: _fade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: EllaColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                '…',
                style: TextStyle(fontSize: 20, color: EllaColors.greenDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SpokenTextFlow splits the text into words and animates each word as it pops
/// into the bubble (using a scale + slide bounce animation).
class SpokenTextFlow extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const SpokenTextFlow({
    super.key,
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final words = text.split(RegExp(r'\s+'));
    return Wrap(
      spacing: 0,
      runSpacing: 4,
      children: List.generate(words.length, (index) {
        final word = words[index];
        return AnimatedWord(
          key: ValueKey('${index}_$word'),
          word: word,
          style: style,
        );
      }),
    );
  }
}

class AnimatedWord extends StatefulWidget {
  final String word;
  final TextStyle? style;

  const AnimatedWord({
    super.key,
    required this.word,
    this.style,
  });

  @override
  State<AnimatedWord> createState() => _AnimatedWordState();
}

class _AnimatedWordState extends State<AnimatedWord> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Spring/bounce curve matching cubic-bezier(.34, 1.56, .64, 1)
    final curve = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.34, 1.56, 0.64, 1.0),
    );

    _scale = Tween<double>(begin: 0.3, end: 1.0).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(curve);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: ScaleTransition(
        scale: _scale,
        child: Text(
          '${widget.word} ',
          style: widget.style,
        ),
      ),
    );
  }
}
