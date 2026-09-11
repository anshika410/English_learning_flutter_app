import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../providers/piper_download_provider.dart';

/// Small pill banner shown while the Piper voice model is downloading.
/// Auto-hides when done or failed.
class PiperDownloadBanner extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;

  const PiperDownloadBanner({
    super.key,
    this.margin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      piperDownloadProvider.select((s) => s.status),
    );

    // Only show while actively downloading
    if (status != PiperDownloadStatus.downloading) {
      return const SizedBox.shrink();
    }

    // Round to nearest 5% so the widget only rebuilds 20 times total, not 100+
    final displayPercent = ref.watch(
      piperDownloadProvider.select((s) => ((s.progress * 100).toInt() ~/ 5) * 5),
    );
    final progressValue = ref.watch(
      piperDownloadProvider.select((s) => s.progress > 0 ? s.progress : null),
    );

    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: EllaColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EllaColors.info.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          children: [
            // Progress indicator
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: progressValue,
                strokeWidth: 2.5,
                color: EllaColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Upgrading voice... $displayPercent%',
                style: EllaTextStyles.bodySemibold.copyWith(
                  fontSize: 12,
                  color: EllaColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
