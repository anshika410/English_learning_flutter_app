import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// App notification service for posting local notifications (e.g. TTS download completion).
class AppNotificationService {
  AppNotificationService._();
  static final AppNotificationService instance = AppNotificationService._();

  static const _smallIcon = '@mipmap/launcher_icon';
  static const _channelId = 'tts_download_channel';
  static const _channelName = 'Voice Downloads';
  static const _channelDescription =
      'Notifications for TTS voice model download completion.';
  static const _notificationId = 0x5454;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize notification plugin and set up channel.
  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );

      await _plugin.initialize(settings: initSettings);

      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
        await android.requestNotificationsPermission();
      }

      _initialized = true;
      debugPrint('AppNotificationService: initialized successfully ✓');
    } catch (e) {
      debugPrint('AppNotificationService: init error: $e');
    }
  }

  /// Show a system notification outside the app when TTS download completes.
  Future<void> showTtsDownloadCompleteNotification({
    String title = 'Voice Model Ready',
    String body = "Ella's voice model has been downloaded successfully!",
  }) async {
    if (kIsWeb) return;
    if (!_initialized) {
      await init();
    }

    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _plugin.show(
        id: _notificationId,
        title: title,
        body: body,
        notificationDetails: details,
      );
      debugPrint('AppNotificationService: completion notification posted ✓');
    } catch (e) {
      debugPrint('AppNotificationService: notify error: $e');
    }
  }
}
