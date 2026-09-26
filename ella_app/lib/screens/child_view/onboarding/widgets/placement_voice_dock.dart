import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/text_styles.dart';
import '../../../../core/theme_colors.dart';
import '../../../../services/audio_service.dart';

class PlacementVoiceDock extends StatelessWidget {
  final bool isListening;
  final bool hasResponse;
  final VoidCallback onMicTap;
  final double? micSize;
  final ValueNotifier<double>? speechLevel;

  const PlacementVoiceDock({
    super.key,
    required this.isListening,
    required this.hasResponse,
    required this.onMicTap,
    this.micSize,
    this.speechLevel,
  });

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final effectiveMicSize = micSize ?? (screenH * 0.11).clamp(72.0, 90.0);
    final fill = isListening ? EllaColors.berryDark : EllaColors.berryMain;
    final edge = EllaColors.berryDeep;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Waveform indicator when listening
        if (isListening) ...[
          _WaveformIndicator(speechLevel: speechLevel),
          const SizedBox(height: 12),
        ],

        // Circular mic button (conversation session style)
        GestureDetector(
          onTap: () {
            playTapClick();
            onMicTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: effectiveMicSize,
            height: effectiveMicSize,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: edge, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: EllaColors.berryDeep,
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: isListening
                  ? SvgPicture.asset(
                      'assets/send-button.svg',
                      width: effectiveMicSize * 0.44,
                      height: effectiveMicSize * 0.44,
                      colorFilter: const ColorFilter.mode(
                        EllaColors.onPrimary,
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(
                      Icons.mic_rounded,
                      size: effectiveMicSize * 0.44,
                      color: EllaColors.onPrimary,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isListening
              ? 'Listening...'
              : (hasResponse ? 'Tap to Record Again' : 'Tap to Speak'),
          style: EllaFonts.body(
            const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: EllaColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _WaveformIndicator extends StatefulWidget {
  final ValueNotifier<double>? speechLevel;

  const _WaveformIndicator({
    this.speechLevel,
  });

  @override
  State<_WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends State<_WaveformIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static final _dummySpeechLevel = ValueNotifier<double>(0.0);

  static const _colors = [
    Color(0xffe4457c),
    Color(0xffa86fd4),
    Color(0xff5f9de8),
    Color(0xffffc93d),
    Color(0xff59a84c),
    Color(0xffe4457c),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = widget.speechLevel ?? _dummySpeechLevel;

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, notifier]),
      builder: (context, _) {
        final level = notifier.value.clamp(0.0, 1.0);

        return Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x66a86fd4), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffe4457c).withValues(alpha: 0.08 + level * 0.20),
                blurRadius: 8 + level * 12,
                spreadRadius: 1 + level * 2.5,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(6, (i) {
              final idleWave = (math.sin(_controller.value * math.pi * 2 + i * 0.9) + 1) / 2;
              final centerBoost = 1.0 - ((i - 2.5).abs() / 3.0);
              final dynamicHeight = (8.0 + idleWave * 6.0 + level * (14.0 + centerBoost * 16.0)).clamp(6.0, 32.0);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOutCubic,
                width: 4.5,
                height: dynamicHeight,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _colors[i % _colors.length],
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
