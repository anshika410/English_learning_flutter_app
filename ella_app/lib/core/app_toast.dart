// Shared app toast. One entry point for every user-facing message so backend /
// network failures always read the same way (no raw exception strings leaking
// through). Built on ScaffoldMessenger's SnackBar — floating, rounded, styled
// with Botanical Berry tokens — and clears any queued snack first so errors
// never stack up.

import 'package:flutter/material.dart';

import 'text_styles.dart';
import 'theme_colors.dart';
import '../services/audio_service.dart';
import '../services/sounds.dart';

/// The single copy shown for any backend / server-side failure across the app.
const String kGenericServerErrorMessage =
    'Something went wrong. Try again';

/// Shows the standard server-error toast. Pass a custom [message] only for a
/// deliberately different, non-server message (input validation stays as its
/// own specific text at the call site).
void showEllaErrorToast(
  BuildContext context, [
  String message = kGenericServerErrorMessage,
]) {
  AudioService.maybeInstance?.playSfx(Sounds.error);
  _show(context, message, background: EllaColors.ink, foreground: EllaColors.onDark);
}

/// Neutral toast for informational / confirmation copy on a light surface.
void showEllaToast(BuildContext context, String message) {
  _show(
    context,
    message,
    background: EllaColors.surface,
    foreground: EllaColors.ink,
  );
}

void _show(
  BuildContext context,
  String message, {
  required Color background,
  required Color foreground,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        elevation: 3,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Text(
          message,
          style: EllaTextStyles.bodySemibold.copyWith(color: foreground),
        ),
      ),
    );
}
