import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/piper_model_service.dart';

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
  @override
  PiperDownloadState build() => const PiperDownloadState();

  Future<void> startIfNeeded() async {
    final modelService = PiperModelService.instance;
    final alreadyDownloaded = await modelService.checkIfDownloaded();
    if (alreadyDownloaded) {
      state = state.copyWith(status: PiperDownloadStatus.done);
      return;
    }

    state = state.copyWith(
      status: PiperDownloadStatus.downloading,
      progress: 0.0,
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

    state = state.copyWith(
      status: success ? PiperDownloadStatus.done : PiperDownloadStatus.failed,
      progress: success ? 1.0 : state.progress,
      message: success ? 'Voice model ready!' : 'Download failed, using default voice',
    );
  }
}

final piperDownloadProvider =
    NotifierProvider<PiperDownloadNotifier, PiperDownloadState>(
  PiperDownloadNotifier.new,
);
