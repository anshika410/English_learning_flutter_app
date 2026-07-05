// Singleton providers for the three injectable services.
// All read from .env (loaded in main.dart before runApp).

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/audio_service.dart';
import '../services/ella_api_service.dart';
import '../services/llm_service.dart';
import '../services/supabase_service.dart';
import '../services/stt_tts_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

final ellaApiServiceProvider = Provider<EllaApiService>((ref) {
  return EllaApiService(
    baseUrl:
        dotenv.env['ELLA_API_BASE_URL'] ?? 'http://192.168.1.7:8000',
  );
});

final llmServiceProvider = Provider<LlmService>((ref) {
  return LlmService(
    proxyUrl: dotenv.env['LLM_PROXY_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
});

final sttProvider = Provider<SpeechToTextService>(
  (ref) => SpeechToTextService(),
);

final ttsProvider = Provider<FlutterTtsService>((ref) => FlutterTtsService());

/// App-wide SFX + background-music player. Initialized once in main().
final audioProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});
