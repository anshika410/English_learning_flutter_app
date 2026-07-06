// Profile tab — placeholder. Fleshed out in a later phase.
// For now it hosts the temporary sound controls (music + SFX mute) until the
// final profile/settings UI arrives. Toggles persist via AudioService.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../providers/service_providers.dart';
import '../../services/ella_api_service.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late bool _musicOn;
  late bool _sfxOn;
  String _appVersion = '';

  // Saved profile (name/age) fetched from GET /users/me. Null while loading;
  // falls back to the local onboarding cache if the network call fails.
  String? _name;
  int? _age;

  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider);
    _musicOn = audio.musicEnabled;
    _sfxOn = audio.sfxEnabled;
    _loadAppVersion();
    _loadProfile();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
    }
  }

  Future<void> _loadProfile() async {
    final api = ref.read(ellaApiServiceProvider);
    // Seed instantly from the local onboarding cache so the card isn't blank
    // while the network call is in flight.
    final cached = await api.getOnboardingState();
    if (mounted) {
      setState(() {
        _name = cached.name;
        _age = cached.age;
      });
    }
    // Then refresh from the server (the source of truth) — best-effort.
    try {
      final profile = await api.getProfile();
      if (mounted && (profile.name != null || profile.age != null)) {
        setState(() {
          _name = profile.name ?? _name;
          _age = profile.age ?? _age;
        });
      }
    } catch (_) {
      // Keep the cached values on a network hiccup.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EllaColors.canvas,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
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
              Text(
                (_name != null && _name!.isNotEmpty) ? _name! : 'Profile',
                style: EllaTextStyles.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _age != null ? 'Age $_age' : ' ',
                style: EllaTextStyles.bodySmall.copyWith(
                  color: EllaColors.textTertiary,
                ),
              ),
              const SizedBox(height: 28),
              _soundControls(),
              const SizedBox(height: 48),
              TextButton.icon(
                onPressed: () async {
                  await EllaApiService().logout();
                  try {
                    await GoogleSignIn.instance.signOut();
                  } catch (_) {}
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true)
                        .pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                icon: const Icon(Icons.logout, color: EllaColors.berryMain),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    color: EllaColors.berryMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: EllaColors.berryMain, width: 2),
                  ),
                ),
              ),
              ],
            ),
          ),
          if (_appVersion.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  _appVersion,
                  style: const TextStyle(
                    color: EllaColors.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
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
