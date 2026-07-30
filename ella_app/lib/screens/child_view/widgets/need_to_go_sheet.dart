// NeedToGoSheet — the back-button "pause" sheet for the conversation screen.
//
// Replaces the old generic "Leave this chat?" dialog. Slides up over a dimmed
// backdrop (Zoe rests in her paused/sway pose behind it) and offers two CTAs:
// a prominent "Keep Talking" (return to the chat) and a secondary "Finish
// Conversation" (end the session → garden). Presentation only: it pops with a
// [NeedToGoResult] and the caller performs the actions.

import 'package:flutter/material.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import 'ella_primary_button.dart';

/// The choice the child made on the "Finish for now?" sheet.
enum NeedToGoResult { keepTalking, leave }

/// Shows the sheet and resolves to the chosen [NeedToGoResult], or `null` if
/// the child dismissed it by tapping the scrim / swiping down (treated as
/// "keep talking" by the caller).
Future<NeedToGoResult?> showNeedToGoSheet(BuildContext context) {
  return showModalBottomSheet<NeedToGoResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // Dim the conversation behind the sheet (Zoe stays visible, paused).
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _NeedToGoSheet(),
  );
}

class _NeedToGoSheet extends StatelessWidget {
  const _NeedToGoSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('need-to-go-sheet'),
        // Garden-sheet recipe, without the border (per design).
        decoration: const BoxDecoration(
          color: EllaColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EllaColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Finish for now?',
              textAlign: TextAlign.center,
              style: EllaTextStyles.titleMedium,
            ),
            const SizedBox(height: 20),
            EllaPrimaryButton(
              label: 'Keep Talking',
              height: 56,
              onTap: () =>
                  Navigator.of(context).pop(NeedToGoResult.keepTalking),
            ),
            const SizedBox(height: 12),
            EllaPrimaryButton(
              label: 'Finish Conversation',
              height: 56,
              variant: EllaButtonVariant.outline,
              onTap: () => Navigator.of(context).pop(NeedToGoResult.leave),
            ),
          ],
        ),
      ),
    );
  }
}
