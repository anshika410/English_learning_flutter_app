import 'dart:async';
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
import 'services/piper_model_service.dart';
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
    
    // Enable Crashlytics collection based on release mode.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    
    await AnalyticsService.logAppOpen();
  } catch (e) {
    debugPrint('⚠️ Firebase initialization failed: $e');
  }

  // Try to initialize Piper on-device TTS (best-effort, non-blocking).
  // If model not downloaded yet, it initializes silently as no-op.
  // Model download happens lazily on first conversation start.
  unawaited(() async {
    try {
      await PiperModelService.instance.checkIfDownloaded();
    } catch (_) {}
  }());
  // Lock app to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  bool isGoogleSignInCancellation(Object? error) {
    if (error == null) return false;
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return true;
      }
    }
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('googlesigninexception') &&
        (errStr.contains('cancel') || errStr.contains('interrupted'))) {
      return true;
    }
    return false;
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔥🔥🔥 FLUTTER ERROR: ${details.exception}');
    debugPrint('🔥🔥🔥 STACK TRACE: ${details.stack}');
    if (isGoogleSignInCancellation(details.exception)) {
      return;
    }
    if (isFirebaseInitialized) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔥🔥🔥 ASYNC ERROR: $error');
    debugPrint('🔥🔥🔥 ASYNC STACK: $stack');
    if (isGoogleSignInCancellation(error)) {
      return true;
    }
    if (isFirebaseInitialized) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  await dotenv.load(fileName: '.env');
  
  try {
    final googleClientId = dotenv.env['GOOGLE_CLIENT_ID'];
    final isApplePlatform = !kIsWeb && 
        (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);
    await GoogleSignIn.instance.initialize(
      clientId: (kIsWeb || isApplePlatform) ? googleClientId : null,
      serverClientId: kIsWeb ? null : googleClientId,
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
