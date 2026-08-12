import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'services/analytics_service.dart';
import 'services/chucker_notifier.dart';
import 'app.dart';
import 'providers/service_providers.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Debug-only: surface Chucker's recorded API calls as a real Android system
  // notification (in the pull-down shade) that opens the request inspector on
  // tap — so traffic is inspectable whenever, not just in the split second an
  // in-app banner is visible. Turn OFF Chucker's own in-app banner so the
  // persistent notification is the only surface. See ChuckerNotifier +
  // EllaApiService (which posts the notification per request).
  if (kDebugMode) {
    ChuckerFlutter.showNotification = false;
    await ChuckerNotifier.instance.init();
  }

  bool isFirebaseInitialized = false;
  try {
    await Firebase.initializeApp();
    isFirebaseInitialized = true;
    
    // Enable Crashlytics collection (enabled by default, but explicitly set here).
    // You can set this to `!kDebugMode` if you want to avoid recording crashes during local development.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    
    await AnalyticsService.logAppOpen();
  } catch (e) {
    debugPrint('⚠️ Firebase initialization failed: $e');
  }
  // Lock app to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔥🔥🔥 FLUTTER ERROR: ${details.exception}');
    debugPrint('🔥🔥🔥 STACK TRACE: ${details.stack}');
    if (isFirebaseInitialized) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔥🔥🔥 ASYNC ERROR: $error');
    debugPrint('🔥🔥🔥 ASYNC STACK: $stack');
    if (isFirebaseInitialized) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  await dotenv.load(fileName: '.env');

  await GoogleSignIn.instance.initialize(
    clientId: kIsWeb ? dotenv.env['GOOGLE_CLIENT_ID'] : null,
    serverClientId: kIsWeb ? null : dotenv.env['GOOGLE_CLIENT_ID'],
  );
  
  try {
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? dotenv.env['GOOGLE_CLIENT_ID'] : null,
      serverClientId: kIsWeb ? null : dotenv.env['GOOGLE_CLIENT_ID'],
    );
  } catch (e) {
    debugPrint('⚠️ Google Sign-In failed to initialize: $e');
  }

  // The Ella REST API is the single backend now; Supabase is only used by the
  // Glass Box (testing) tabs. Initialize it best-effort so a missing/blank
  // SUPABASE_URL no longer crashes boot.
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
  if (supabaseUrl != null &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    } catch (_) {
      // Non-fatal — chat runs entirely on the Ella API.
    }
  }

  // Shared container so the audio service initialized here is the same instance
  // the widget tree reads via `audioProvider`.
  final container = ProviderContainer();
  // Best-effort: load mute prefs + warm up players. Never block boot on audio.
  try {
    await container.read(audioProvider).initialize();
  } catch (_) {}

  runApp(
    UncontrolledProviderScope(container: container, child: const EllaApp()),
  );
}
