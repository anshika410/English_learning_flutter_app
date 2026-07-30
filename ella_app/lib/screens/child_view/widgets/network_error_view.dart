import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import 'ella_primary_button.dart';
import 'home_scene_background.dart';
import 'zoe_mascot.dart';

bool isNetworkError(Object error) {
  if (error is SocketException ||
      error is HttpException ||
      error is TimeoutException) {
    return true;
  }
  final errStr = error.toString().toLowerCase();
  if (errStr.contains('socketexception') ||
      errStr.contains('httpstatuscodeexception') ||
      errStr.contains('timeoutexception') ||
      errStr.contains('network') ||
      errStr.contains('failed host lookup') ||
      errStr.contains('connection failed') ||
      errStr.contains('connection timed out')) {
    return true;
  }
  return false;
}

class NetworkErrorView extends ConsumerWidget {
  final String message;
  final VoidCallback onRetry;
  final ContentBackgroundBuilder? backgroundBuilder;

  const NetworkErrorView({
    super.key,
    this.message = 'Please check your internet connection and try again.',
    required this.onRetry,
    this.backgroundBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final mascotSize = (MediaQuery.sizeOf(context).shortestSide * 0.42).clamp(
      132.0,
      180.0,
    );

    final content = Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ZoeMascot(
                  mode: ZoeMascotMode.listening,
                  size: mascotSize,
                  reducedMotion: reducedMotion,
                ),
                const SizedBox(height: 24),
                Text(
                  "No Internet Connection",
                  textAlign: TextAlign.center,
                  style: EllaTextStyles.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: EllaTextStyles.authBody.copyWith(
                    color: EllaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 200,
                  child: EllaPrimaryButton(
                    label: 'Refresh',
                    height: 56,
                    leading: const Icon(
                      Icons.refresh_rounded,
                      color: EllaColors.onPrimary,
                      size: 24,
                    ),
                    onTap: onRetry,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return backgroundBuilder?.call(content) ??
        HomeSceneBackground(child: content);
  }
}
