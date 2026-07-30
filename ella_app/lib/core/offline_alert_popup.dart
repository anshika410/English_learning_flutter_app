import 'package:flutter/material.dart';
import 'theme_colors.dart';
import 'text_styles.dart';
import '../screens/child_view/widgets/ella_primary_button.dart';

class OfflineAlertPopup extends StatelessWidget {
  final String text;

  const OfflineAlertPopup({super.key, required this.text});

  static void show(BuildContext context, {String text = "You're offline. Connect to the internet, then try again"}) {
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
              style: EllaTextStyles.bodySemiboldLarge,
            ),
            const SizedBox(height: 32),
            EllaPrimaryButton(
              label: 'Close',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
