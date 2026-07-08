// Shared "Type your reply…" composer (Figma "English App" node 441:26724 /
// 598:15522). One text-entry component reused everywhere the child types:
// the placement/conversation dock and the name/age onboarding step. A 72px
// rounded-20 surface field sits beside a 72px round berry send button carrying
// the paper-plane glyph, so every input point reads identically.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/ella_smooth_shape.dart';
import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import 'ella_primary_button.dart' show EllaIconButton;

const String _kPaperPlaneIcon = 'assets/auth/paper-plane-right.svg';

class ChatReplyComposer extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;

  /// When false the send button is disabled (greyed, non-tappable). The field
  /// itself stays editable.
  final bool enabled;
  final String hintText;
  final VoidCallback? onSend;
  final TextInputType keyboardType;

  const ChatReplyComposer({
    super.key,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.hintText = 'Type your reply...',
    this.onSend,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: ellaSmoothDecoration(
              color: EllaColors.surface,
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: EllaColors.border, width: 1),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              minLines: 1,
              maxLines: 3,
              keyboardType: keyboardType,
              inputFormatters: keyboardType == TextInputType.number
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              textInputAction: TextInputAction.send,
              textCapitalization: keyboardType == TextInputType.number
                  ? TextCapitalization.none
                  : TextCapitalization.sentences,
              onSubmitted: onSend == null ? null : (_) => onSend!(),
              style: EllaTextStyles.bodySemiboldLarge,
              cursorColor: EllaColors.berryDark,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: EllaTextStyles.bodySemiboldLarge.copyWith(
                  color: EllaColors.textTertiary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        EllaIconButton(
          key: const ValueKey('chat-reply-send'),
          size: 72,
          onTap: enabled ? onSend : null,
          glyph: SvgPicture.asset(_kPaperPlaneIcon, width: 24, height: 24),
        ),
      ],
    );
  }
}
