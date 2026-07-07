import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isZoe = message.sender == MessageSender.zoe;

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
                  child: _TypewriterText(text: message.text),
                )
              : DottedBorder(
                  color: const Color(0xFFE91E63),
                  strokeWidth: 2.5,
                  dashPattern: const [8, 4],
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(18),
                  padding: EdgeInsets.zero,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      message.text,
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

/// Reveals text word-by-word with a typing animation for Zoe's messages.
/// Also supports karaoke highlight when [highlightStart] and [highlightEnd] are provided.
class _TypewriterText extends StatefulWidget {
  final String text;
  final int highlightStart;
  final int highlightEnd;
  const _TypewriterText({required this.text, this.highlightStart = -1, this.highlightEnd = -1});

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  late List<String> _words;
  int _visibleWords = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _words = widget.text.split(' ');
    _animate();
  }

  void _animate() async {
    for (int i = 1; i <= _words.length; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      setState(() => _visibleWords = i);
    }
    if (mounted) setState(() => _done = true);
  }

  @override
  void didUpdateWidget(covariant _TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _words = widget.text.split(' ');
      _visibleWords = 0;
      _done = false;
      _animate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _done
        ? widget.text
        : _words.take(_visibleWords).join(' ');

    // If we have highlight range, build RichText with highlighted span
    if (_done && widget.highlightStart >= 0 && widget.highlightEnd > widget.highlightStart && widget.highlightEnd <= widget.text.length) {
      return RichText(
        text: TextSpan(
          style: EllaTextStyles.bodyBase.copyWith(color: EllaColors.ink, height: 1.4),
          children: [
            TextSpan(text: widget.text.substring(0, widget.highlightStart)),
            TextSpan(
              text: widget.text.substring(widget.highlightStart, widget.highlightEnd),
              style: EllaTextStyles.bodyBase.copyWith(
                color: const Color(0xFFE91E63),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            TextSpan(text: widget.text.substring(widget.highlightEnd)),
          ],
        ),
      );
    }

    return Text(
      displayed,
      style: EllaTextStyles.bodyBase.copyWith(
        color: EllaColors.ink,
        height: 1.4,
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
