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

  const PlacementVoiceDock({
    super.key,
    required this.isListening,
    required this.hasResponse,
    required this.onMicTap,
  });

  static const double _micSize = 90;

  @override
  Widget build(BuildContext context) {
    final fill = isListening ? EllaColors.berryDark : EllaColors.berryMain;
    final edge = EllaColors.berryDeep;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Waveform indicator when listening
        if (isListening) ...[
          const _WaveformIndicator(),
          const SizedBox(height: 16),
        ],

        // Circular mic button (conversation session style)
        GestureDetector(
          onTap: () {
            playTapClick();
            onMicTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _micSize,
            height: _micSize,
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
                      width: _micSize * 0.44,
                      height: _micSize * 0.44,
                      colorFilter: const ColorFilter.mode(
                        EllaColors.onPrimary,
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(
                      Icons.mic_rounded,
                      size: _micSize * 0.44,
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
  const _WaveformIndicator();

  @override
  State<_WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends State<_WaveformIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x66a86fd4), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffe4457c).withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(6, (i) {
              final wave = (math.sin(_controller.value * math.pi * 2 + i * 0.9) + 1) / 2;
              final height = 10 + wave * 16;
              return Container(
                width: 4,
                height: height,
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
