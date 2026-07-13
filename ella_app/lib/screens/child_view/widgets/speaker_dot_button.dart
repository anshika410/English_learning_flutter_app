// Circular speaker button (Figma "Placement Flow") — a berry dot with a white
// speaker glyph that straddles the top-right border of a message bubble and
// replays the line via TTS. The glyph never changes; while the line is already
// being spoken ([active]) taps are ignored so the utterance can't be restarted
// or stacked.
//
// Place inside a Stack(clipBehavior: Clip.none) with a Positioned so the dot
// overhangs the bubble edge; give the bubble headroom so it isn't clipped.

import 'package:flutter/material.dart';

import '../../../core/theme_colors.dart';
import '../../../services/audio_service.dart';

class SpeakerDotButton extends StatelessWidget {
  /// True while the line is being spoken — taps are ignored until it finishes.
  final bool active;
  final VoidCallback? onTap;
  final double size;

  const SpeakerDotButton({
    super.key,
    required this.active,
    required this.onTap,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: active ? 'Mute' : 'Speak again',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : withTapClick(onTap!),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? EllaColors.berryDark : EllaColors.berryMain,
            shape: BoxShape.circle,
            border: Border.all(color: EllaColors.berryDeep, width: 2),
          ),
          child: Icon(
            active ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            size: size * 0.55,
            color: EllaColors.onPrimary,
          ),
        ),
      ),
    );
  }
}
