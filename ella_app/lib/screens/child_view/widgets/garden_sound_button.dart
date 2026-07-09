// Garden sound toggle — a round speaker button shown on every garden screen so
// the child can mute/unmute the ambient loop without leaving for Profile.
//
// It toggles the SAME global `musicEnabled` flag the Profile screen owns (via
// AudioService, persisted in SharedPreferences), so muting here mutes music
// everywhere and vice-versa. The glyph reflects the live state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme_colors.dart';
import '../../../providers/service_providers.dart';
import '../../../services/audio_service.dart';

class GardenSoundButton extends ConsumerStatefulWidget {
  final double size;

  const GardenSoundButton({super.key, this.size = 40});

  @override
  ConsumerState<GardenSoundButton> createState() => _GardenSoundButtonState();
}

class _GardenSoundButtonState extends ConsumerState<GardenSoundButton> {
  late bool _on;

  @override
  void initState() {
    super.initState();
    _on = ref.read(audioProvider).musicEnabled;
  }

  Future<void> _toggle() async {
    final next = !_on;
    setState(() => _on = next);
    // Flips the global music flag: enabling resumes the current (garden) loop,
    // disabling stops it — and the Profile toggle stays in sync since both read
    // the same persisted flag.
    await ref.read(audioProvider).setMusicEnabled(next);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _on ? 'Mute garden sound' : 'Unmute garden sound',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: withTapClick(_toggle),
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EllaColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: _on ? EllaColors.berryDark : EllaColors.textTertiary,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(
            _on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            size: widget.size * 0.5,
            color: _on ? EllaColors.berryDark : EllaColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
