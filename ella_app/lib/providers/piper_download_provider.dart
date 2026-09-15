import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/piper_model_service.dart';
import '../services/app_notification_service.dart';
import 'connectivity_provider.dart';
import 'service_providers.dart';

enum PiperDownloadStatus { idle, downloading, done, failed }

class PiperDownloadState {
  final PiperDownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String message;

  const PiperDownloadState({
    this.status = PiperDownloadStatus.idle,
    this.progress = 0.0,
    this.message = '',
  });

  PiperDownloadState copyWith({
    PiperDownloadStatus? status,
    double? progress,
    String? message,
  }) => PiperDownloadState(
    status: status ?? this.status,
    progress: progress ?? this.progress,
    message: message ?? this.message,
  );
}

class PiperDownloadNotifier extends Notifier<PiperDownloadState> {
  bool _isDownloading = false;

  @override
  PiperDownloadState build() {
    // Listen for network connectivity restoration. Automatically resume download
    // if internet connection drops and returns.
    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      final isOnline = next.value ?? false;
      if (isOnline &&
          !_isDownloading &&
          (state.status == PiperDownloadStatus.failed ||
           state.status == PiperDownloadStatus.idle)) {
        debugPrint('PiperDownloadNotifier: network restored, attempting auto-resume');
        startIfNeeded();
      }
    });

    return const PiperDownloadState();
  }

  Future<void> startIfNeeded() async {
    if (_isDownloading) return;

    final modelService = PiperModelService.instance;
    final alreadyDownloaded = await modelService.checkIfDownloaded();
    if (alreadyDownloaded) {
      state = state.copyWith(
        status: PiperDownloadStatus.done,
        progress: 1.0,
        message: 'Voice model ready!',
      );
      return;
    }

    _isDownloading = true;
    state = state.copyWith(
      status: PiperDownloadStatus.downloading,
      message: 'Downloading voice model...',
    );

    final success = await modelService.downloadModel(
      onProgress: (progress, message) {
        state = state.copyWith(
          progress: progress,
          message: message,
        );
      },
    );

    _isDownloading = false;

    state = state.copyWith(
      status: success ? PiperDownloadStatus.done : PiperDownloadStatus.failed,
      progress: success ? 1.0 : state.progress,
      message: success
          ? 'Voice model ready!'
          : 'Download failed, will auto-resume when online',
    );

    // After successful download, post system notification and initialize TTS service
    if (success) {
      try {
        await AppNotificationService.instance.showTtsDownloadCompleteNotification(
          title: 'Voice Model Ready',
          body: "Ella's voice model has been downloaded successfully!",
        );
      } catch (e) {
        debugPrint('PiperDownloadNotifier: failed to post completion notification: $e');
      }

      try {
        final piperService = ref.read(piperTtsProvider);
        await piperService.initialize();
      } catch (_) {}
    }
  }
}

final piperDownloadProvider =
    NotifierProvider<PiperDownloadNotifier, PiperDownloadState>(
  PiperDownloadNotifier.new,
);
