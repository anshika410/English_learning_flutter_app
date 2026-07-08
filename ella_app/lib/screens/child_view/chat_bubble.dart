import 'package:flutter/material.dart';

import '../../core/ella_smooth_shape.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/message.dart';

class ChatBubble extends ConsumerWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: ellaSmoothDecoration(
                // Child bubble uses greenMain (ink text = 7.29:1, AA); white on
                // greenDark would fail. Zoe bubble is a plain surface.
                color: isZoe ? EllaColors.surface : EllaColors.greenMain,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isZoe ? 4 : 18),
                  bottomRight: Radius.circular(isZoe ? 18 : 4),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: EllaTextStyles.bodyBase.copyWith(
                  color: EllaColors.ink,
                  height: 1.4,
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
class TypewriterText extends StatefulWidget {
  final String text;
  final int highlightStart;
  final int highlightEnd;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final bool animate;

  const TypewriterText({
    super.key,
    required this.text,
    this.highlightStart = -1,
    this.highlightEnd = -1,
    this.style,
    this.highlightStyle,
    this.animate = true,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  late List<String> _words;
  int _visibleWords = 0;
  bool _done = false;
  int _animationId = 0;

  @override
  void initState() {
    super.initState();
    _words = widget.text.split(' ');
    if (widget.animate) {
      _animate();
    } else {
      _visibleWords = _words.length;
      _done = true;
    }
  }

  void _animate() async {
    final currentId = ++_animationId;
    for (int i = 1; i <= _words.length; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted || _animationId != currentId) return;
      setState(() => _visibleWords = i);
    }
    if (mounted && _animationId == currentId) {
      setState(() => _done = true);
    }
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _words = widget.text.split(' ');
      if (widget.animate) {
        _visibleWords = 0;
        _done = false;
        _animate();
      } else {
        _visibleWords = _words.length;
        _done = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _done
        ? widget.text
        : _words.take(_visibleWords).join(' ');

    final baseStyle = widget.style ??
        EllaTextStyles.bodyBase.copyWith(color: EllaColors.ink, height: 1.4);
    final highlightStyle = widget.highlightStyle ??
        baseStyle.copyWith(
          color: const Color(0xFFE91E63),
        );

    // If we have highlight range, build RichText with highlighted span
    if (_done &&
        widget.highlightStart >= 0 &&
        widget.highlightEnd > widget.highlightStart &&
        widget.highlightEnd <= widget.text.length) {
      return RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: widget.text.substring(0, widget.highlightStart)),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Transform.scale(
                scale: 1.12, // Magnify the active word by 12% without shifting text layout
                child: Text(
                  widget.text.substring(
                    widget.highlightStart,
                    widget.highlightEnd,
                  ),
                  style: highlightStyle,
                ),
              ),
            ),
            TextSpan(text: widget.text.substring(widget.highlightEnd)),
          ],
        ),
      );
    }

    return _done
        ? MarkdownBody(
            data: widget.text,
            styleSheet: MarkdownStyleSheet(
              p: baseStyle,
              strong: baseStyle.copyWith(fontWeight: FontWeight.w700),
              em: baseStyle.copyWith(fontStyle: FontStyle.italic),
              code: baseStyle.copyWith(
                fontFamily: 'monospace',
                color: EllaColors.greenDark,
                backgroundColor: const Color(0xFFE8F5E9),
              ),
            ),
            softLineBreak: true,
          )
        : Text(
            displayed,
            style: baseStyle,
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
              decoration: ellaSmoothDecoration(
                color: EllaColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                shadows: [
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
