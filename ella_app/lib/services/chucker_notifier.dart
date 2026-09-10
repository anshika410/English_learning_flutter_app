import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Debug-only bridge that surfaces Chucker's recorded API calls as a real
/// **Android system notification** (in the pull-down shade) instead of
/// Chucker's transient in-app banner. The notification is sticky, updates in
/// place on every call, and opens the Chucker request inspector when tapped —
/// so you can inspect traffic whenever you want, not only in the split second
/// the in-app banner is on screen.
///
/// Every method is a safe no-op unless [init] has completed on a debug build,
/// so it's harmless in release and in unit tests (which never call [init]).
class ChuckerNotifier {
  ChuckerNotifier._();
  static final ChuckerNotifier instance = ChuckerNotifier._();

  // Small-icon uses the app launcher icon (declared in AndroidManifest).
  static const _smallIcon = '@mipmap/launcher_icon';
  static const _channelId = 'chucker_api_inspector';
  static const _channelName = 'API Inspector (debug)';
  static const _channelDescription =
      'Shows every API request Chucker recorded. Debug builds only.';
  // Fixed id → each call updates the same notification instead of stacking.
  static const _notificationId = 0x0C;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _count = 0;

  /// Wire up the plugin, notification channel, and runtime permission. Called
  /// once from `main()` (debug only). Silently does nothing on release builds.
  Future<void> init() async {
    if (!kDebugMode || _ready) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings(_smallIcon),
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (_) => _openInspector(),
    );

    final android =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        // Low: it shows in the shade but never buzzes/heads-up per request.
        importance: Importance.low,
      ),
    );
    // Android 13+ (API 33) requires runtime consent to post notifications.
    await android?.requestNotificationsPermission();

    _ready = true;
  }

  /// Post/refresh the single inspector notification with the latest call.
  /// Fire-and-forget; safe to call from any request path.
  Future<void> notify({
    required String method,
    required String path,
    required int statusCode,
  }) async {
    if (kIsWeb || !_ready) return;
    _count++;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        // Update quietly (no re-alert each call) and keep it in the shade.
        onlyAlertOnce: true,
        autoCancel: false,
        ongoing: true,
        showWhen: true,
      ),
    );
    await _plugin.show(
      id: _notificationId,
      title: 'API Inspector · $_count call${_count == 1 ? '' : 's'}',
      body: '$method $path → $statusCode   (tap to inspect)',
      notificationDetails: details,
    );
  }

  void _openInspector() {
    // Defer to the next frame so the navigator is attached when resuming from
    // background via a notification tap.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ChuckerFlutter.showChuckerScreen(),
    );
  }
}
