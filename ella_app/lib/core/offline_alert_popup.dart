import 'package:flutter/material.dart';
import 'theme_colors.dart';
import 'text_styles.dart';
import '../screens/child_view/widgets/ella_primary_button.dart';

class OfflineAlertPopup extends StatelessWidget {
  final String text;

  const OfflineAlertPopup({super.key, required this.text});

  static void show(BuildContext context, {String text = "Oops! I need the internet to do that."}) {
    showDialog(
      context: context,
      builder: (context) => OfflineAlertPopup(text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EllaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: EllaColors.berryMain,
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: EllaTextStyles.headline.copyWith(color: EllaColors.ink, fontSize: 24),
            ),
            const SizedBox(height: 32),
            EllaPrimaryButton(
              label: 'OK',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
