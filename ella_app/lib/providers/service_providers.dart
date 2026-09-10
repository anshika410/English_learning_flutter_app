// Singleton providers for the three injectable services.
// All read from .env (loaded in main.dart before runApp).

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/audio_service.dart';
import '../services/ella_api_service.dart';
import '../services/supabase_service.dart';
import '../services/stt_tts_service.dart';
import '../services/native_tts_service.dart';
import '../services/piper_tts_service.dart';
import '../services/piper_model_service.dart';
import '../providers/piper_download_provider.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

final ellaApiServiceProvider = Provider<EllaApiService>((ref) {
  return EllaApiService(
    baseUrl:
        dotenv.env['ELLA_API_BASE_URL'] ?? 'https://ella.navgurukul.org/api',
  );
});

final sttProvider = Provider<SpeechToTextService>(
  (ref) => SpeechToTextService(),
);

final sttLevelProvider = Provider<ValueNotifier<double>>((ref) {
  return ref.watch(sttProvider).speechLevel;
});

/// Piper on-device TTS (Indian accent model).
/// Used as primary TTS if model is downloaded, falls back to native otherwise.
final piperTtsProvider = Provider<PiperTtsService>((ref) {
  final service = PiperTtsService();
  ref.onDispose(service.dispose);
  return service;
});

/// ttsProvider: uses Piper if model is ready, otherwise NativeTts.
/// Both implement TtsInterface so all consumers are unaffected.
/// Watches piperDownloadProvider so it switches to Piper after download completes.
final ttsProvider = Provider<TtsInterface>((ref) {
  final downloadState = ref.watch(piperDownloadProvider);
  final modelReady = downloadState.status == PiperDownloadStatus.done &&
      PiperModelService.instance.isReady;
  if (modelReady) {
    return ref.read(piperTtsProvider);
  }
  return ref.read(nativeTtsProvider);
});

/// Native Android TTS with karaoke word-highlight support.
final nativeTtsProvider = Provider<NativeTtsService>((ref) {
  final service = NativeTtsService();
  ref.onDispose(service.dispose);
  return service;
});

/// App-wide SFX + background-music player. Initialized once in main().
final audioProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});
