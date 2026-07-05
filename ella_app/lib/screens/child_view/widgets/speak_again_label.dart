// "🔊 Speak Again" affordance — a speaker glyph + label in the berry brand
// colour (#E84A8A) that replays a line via TTS when tapped. Shared between the
// home "Last time" recap card and Zoe's chat bubble so the interaction reads
// the same everywhere.

import 'package:flutter/material.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../services/audio_service.dart';

class SpeakAgainLabel extends StatelessWidget {
  final VoidCallback onTap;
  const SpeakAgainLabel({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withTapClick(onTap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.volume_up_rounded,
            size: 16,
            color: EllaColors.berryMain,
          ),
          const SizedBox(width: 6),
          Text(
            'Speak Again',
            style: EllaTextStyles.caption.copyWith(color: EllaColors.berryMain),
          ),
        ],
      ),
    );
  }
}
