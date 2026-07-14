import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  /// Checks for an update and prompts the user if one is available.
  static Future<void> checkForUpdates() async {
    // In-app updates are only supported on Android.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final info = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 3));
      
      // If an update is available, trigger an immediate update.
      // (Can also use InAppUpdate.startFlexibleUpdate() if desired)
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      // It's normal for this to throw exceptions during local development 
      // (e.g., when the app is installed via USB, not the Play Store)
      debugPrint('InAppUpdate exception: $e');
    }
  }
}
