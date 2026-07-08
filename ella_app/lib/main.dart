import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app.dart';
import 'providers/service_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔥🔥🔥 FLUTTER ERROR: ${details.exception}');
    debugPrint('🔥🔥🔥 STACK TRACE: ${details.stack}');
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔥🔥🔥 ASYNC ERROR: $error');
    debugPrint('🔥🔥🔥 ASYNC STACK: $stack');
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
