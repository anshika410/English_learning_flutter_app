import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme_colors.dart';
import '../../core/text_styles.dart';
import '../../core/offline_alert_popup.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/placement_provider.dart';
import '../../services/ella_api_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'widgets/profile_scenery.dart';
import 'widgets/sound_toggle.dart';
import 'widgets/edit_profile_dialog.dart';
import 'widgets/mascot_loading_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _asset = 'assets/profile';

  late bool _sfxOn;

  bool _isLoading = true;
  String _name = '';
  int _age = 0;

  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioProvider);
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
    final cache = await EllaApiService().getOnboardingState();
    final providerName = ref.read(onboardingProvider).valueOrNull?.name;
    final fallbackName = providerName ?? cache.name ?? '';
    final fallbackAge = cache.age ?? 0;

    try {
      final profile = await EllaApiService().getUserProfile();
      if (mounted) {
        setState(() {
          final profMap = profile['profile'] as Map<String, dynamic>? ?? {};
          _name = profMap['name'] as String? ?? fallbackName;
          if (_name.isEmpty) _name = fallbackName;
          if (_name.isEmpty) _name = 'Student';

          final ageVal = profMap['age'];
          if (ageVal is num) {
            _age = ageVal.toInt();
          } else if (ageVal is String) {
            _age = int.tryParse(ageVal) ?? fallbackAge;
          } else {
            _age = fallbackAge;
          }
          if (_age == 0) _age = fallbackAge;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load profile from API, checking local cache: $e');
      if (mounted) {
        setState(() {
          _name = fallbackName.isEmpty ? 'Student' : fallbackName;
          _age = fallbackAge;
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _handleSignOut() async {
    final isOnline = ref.read(connectivityProvider).value ?? true;
    if (!isOnline) {
      OfflineAlertPopup.show(context);
      return;
    }

    await EllaApiService().logout();

    // Invalidate global state providers so user data doesn't leak into the next session
    ref.invalidate(onboardingProvider);
    ref.invalidate(placementProvider);
    ref.invalidate(chatProvider);

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _handleEditProfile() async {
    final isOnline = ref.read(connectivityProvider).value ?? true;
    if (!isOnline) {
      OfflineAlertPopup.show(context);
      return;
    }

    final updated = await EditProfileDialog.show(context, _name, _age);
    if (updated == true) {
      setState(() => _isLoading = true);
      _loadProfile();
    }
  }

  // ── Text styles (Amulya = display/title, Synonym = body) ────────────────
  TextStyle get _displayName => EllaFonts.bricolage(const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.6,
        letterSpacing: 0.04,
        color: EllaColors.ink,
      ));

  TextStyle get _bodySemibold => EllaFonts.body(const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.6,
        color: EllaColors.ink,
      ));

  Future<void> _handleDeleteAccount() async {
    final isOnline = ref.read(connectivityProvider).value ?? true;
    if (!isOnline) {
      OfflineAlertPopup.show(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('Are you sure you want to permanently delete your account? This will erase all your data and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Account', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      if (mounted) setState(() => _isLoading = true);
      try {
        await EllaApiService().deleteAccount();
        if (!context.mounted) return;
        
        // Same sign out logic
        await EllaApiService().logout();
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
        
        // Invalidate global state providers so user data doesn't leak into the next session
        ref.invalidate(chatProvider);
        ref.invalidate(onboardingProvider);
        ref.invalidate(placementProvider);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully.')),
        );
        
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('API Error'),
              content: SingleChildScrollView(child: Text('$e')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MascotLoadingScreen(message: 'Loading profile...');
    }

    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: EllaColors.canvas,
      body: ProfileScenery(
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar: back + Edit Profile ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: EllaColors.berryLight,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: EllaColors.berryMain, width: 3),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 22,
                          color: EllaColors.berryMain,
                        ),
                      ),
                    ),
                    _PillButton(
                      icon: SvgPicture.asset('$_asset/pencil.svg',
                          width: 24, height: 24),
                      label: 'Edit Profile',
                      fill: EllaColors.errorLight,
                      border: EllaColors.errorDark,
                      foreground: EllaColors.errorDark,
                      height: 40,
                      onTap: _handleEditProfile,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(flex: 1),
                      // ── Avatar ────────────────────────────────────────
                      Container(
                        width: 100,
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: EllaColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: EllaColors.border, width: 3),
                        ),
                        child: Text(initial, style: _displayName.copyWith(fontSize: 28)),
                      ),

                      const Spacer(flex: 1),
                      // ── Name ──────────────────────────────────────────
                      Text(_name, textAlign: TextAlign.center, style: _displayName.copyWith(fontSize: 28)),

                      const Spacer(flex: 1),
                      // ── Age badge ─────────────────────────────────────
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: EllaColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: EllaColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset('$_asset/balloon.svg',
                                width: 20, height: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Age $_age',
                              style: _bodySemibold.copyWith(
                                  fontSize: 16,
                                  color: EllaColors.warningDark),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 2),
                      // ── Sound Effects card ────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: EllaColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: EllaColors.textDisabled, width: 3),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset('$_asset/speaker.svg',
                                width: 28, height: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Sound Effects', style: _bodySemibold.copyWith(fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Music & Tap Sounds',
                                    style: EllaFonts.body(const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                      color: EllaColors.ink,
                                    )),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SoundToggle(
                              value: _sfxOn,
                              onChanged: (v) {
                                setState(() {
                                  _sfxOn = v;
                                });
                                ref.read(audioProvider).setSfxEnabled(v);
                                ref.read(audioProvider).setMusicEnabled(v);
                              },
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 2),
                      // ── Sign Out ──────────────────────────────────────
                      _PillButton(
                        icon: SvgPicture.asset('$_asset/sign-out.svg',
                            width: 20, height: 20),
                        label: 'Sign Out',
                        fill: EllaColors.errorLight,
                        border: EllaColors.errorDark,
                        foreground: EllaColors.errorDark,
                        height: 48,
                        dropShadow: EllaColors.berryDeep,
                        onTap: _handleSignOut,
                      ),

                      const SizedBox(height: 12),
                      // ── Delete Account ────────────────────────────────
                      TextButton(
                        onPressed: _handleDeleteAccount,
                        child: const Text(
                          'Delete Account',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),
                      // ── Footer ────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _footerLink(
                            svg: '$_asset/keyhole.svg',
                            label: 'Privacy Policy',
                            onTap: () => Navigator.of(context)
                                .pushNamed('/privacy-policy'),
                          ),
                          const SizedBox(width: 20),
                          _footerLink(
                            svg: '$_asset/address-book.svg',
                            label: 'Contact Us',
                            onTap: () {},
                          ),
                        ],
                      ),

                      const Spacer(flex: 1),
                      if (_appVersion.isNotEmpty)
                        Text(
                          _appVersion,
                          style: EllaFonts.body(const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: EllaColors.textTertiary,
                          )),
                        ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerLink({
    required String svg,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(svg, width: 20, height: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: _bodySemibold.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Rounded "chunky" pill button used for Edit Profile / Sign Out / Delete
/// Memory. [dropShadow] adds the design's solid 3px bottom shadow.
class _PillButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color fill;
  final Color border;
  final Color foreground;
  final double height;
  final Color? dropShadow;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.fill,
    required this.border,
    required this.foreground,
    required this.height,
    required this.onTap,
    this.dropShadow,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: border, width: 3),
          boxShadow: dropShadow == null
              ? null
              : [
                  BoxShadow(
                    color: dropShadow!,
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: EllaFonts.body(TextStyle(
                fontSize: height <= 48 ? 16 : 18,
                fontWeight: FontWeight.w600,
                height: 1.6,
                color: foreground,
              )),
            ),
          ],
        ),
      ),
    );
  }
}
