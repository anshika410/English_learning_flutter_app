// Profile tab — placeholder. Fleshed out in a later phase.
// For now it hosts the temporary sound controls (music + SFX mute) until the
// final profile/settings UI arrives. Toggles persist via AudioService.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../providers/service_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late bool _musicOn;
  late bool _sfxOn;

  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider);
    _musicOn = audio.musicEnabled;
    _sfxOn = audio.sfxEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EllaColors.canvas,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/bottom_tab/profile-svgrepo-com.svg',
                width: 56,
                colorFilter: const ColorFilter.mode(
                  EllaColors.textTertiary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 12),
              Text('Profile', style: EllaTextStyles.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Coming soon',
                style: EllaTextStyles.bodySmall.copyWith(
                  color: EllaColors.textTertiary,
                ),
              ),
              const SizedBox(height: 28),
              _soundControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _soundControls() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SOUND',
              style: EllaTextStyles.caption.copyWith(
                color: EllaColors.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Music', style: EllaTextStyles.bodyBase),
              secondary: const Icon(Icons.music_note_rounded),
              value: _musicOn,
              onChanged: (v) {
                setState(() => _musicOn = v);
                ref.read(audioProvider).setMusicEnabled(v);
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Sound effects', style: EllaTextStyles.bodyBase),
              secondary: const Icon(Icons.volume_up_rounded),
              value: _sfxOn,
              onChanged: (v) {
                setState(() => _sfxOn = v);
                ref.read(audioProvider).setSfxEnabled(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
