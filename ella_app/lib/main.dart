import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'providers/service_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

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
