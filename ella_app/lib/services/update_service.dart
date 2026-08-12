import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  /// Checks for an update and prompts the user if one is available.
  static Future<void> checkForUpdates() async {
    // In-app updates are only supported on Android.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final info = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 3));
      
      // If a flexible update has already been downloaded and is ready to install,
      // apply it now (which will restart the app).
      if (info.installStatus == InstallStatus.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }

      // If a new update is available on the Play Store, trigger a flexible update
      if (info.updateAvailability == UpdateAvailability.updateAvailable && info.flexibleUpdateAllowed) {
        // Prompts the user to update. If they accept, the download starts in the background.
        // This future resolves once the user makes a choice (accept/decline), NOT when download finishes.
        await InAppUpdate.startFlexibleUpdate();
      }
    } catch (e) {
      // It's normal for this to throw exceptions during local development 
      // (e.g., when the app is installed via USB, not the Play Store)
      debugPrint('InAppUpdate exception: $e');
    }
  }
}
