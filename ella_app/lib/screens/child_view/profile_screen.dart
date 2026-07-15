import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../core/offline_alert_popup.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/placement_provider.dart';
import '../../services/ella_api_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'widgets/edit_profile_dialog.dart';
import 'widgets/mascot_loading_screen.dart';
import 'widgets/profile_scenery.dart';

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
  String _email = '';

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
          debugPrint('FULL PROFILE RESPONSE: $profile');

          _name = profMap['name'] as String? ?? fallbackName;
          if (_name.isEmpty) _name = fallbackName;
          if (_name.isEmpty) _name = 'Student';

          _email =
              (profile['email'] as String?) ??
              (profMap['email'] as String?) ??
              'No email found';

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

    await ref.read(onboardingProvider.notifier).reset();
    ref.invalidate(placementProvider);
    ref.invalidate(chatProvider);

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (route) => false);
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
        content: const Text(
          'Are you sure you want to permanently delete your account? This will erase all your data and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) setState(() => _isLoading = true);
      try {
        await EllaApiService().deleteAccount();
        if (!context.mounted) return;

        await EllaApiService().logout();
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}

        ref.invalidate(chatProvider);
        await ref.read(onboardingProvider.notifier).reset();
        ref.invalidate(placementProvider);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully.')),
        );

        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('API Error'),
              content: SingleChildScrollView(child: Text('$e')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
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
              // Top Bar outside scroll view
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
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
                          border: Border.all(
                            color: EllaColors.berryMain,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 22,
                          color: EllaColors.berryMain,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleEditProfile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: EllaColors.errorLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: EllaColors.errorDark,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              '$_asset/pencil.svg',
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                EllaColors.errorDark,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Edit Profile',
                              style: EllaFonts.body(
                                const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: EllaColors.errorDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Shortest height the content can lay out at; on shorter
                    // screens the whole section scales down uniformly so the
                    // screen never scrolls.
                    const minContentHeight = 660.0;
                    final scale = constraints.maxHeight / minContentHeight;
                    final content = SizedBox(
                      width: scale < 1
                          ? constraints.maxWidth / scale
                          : constraints.maxWidth,
                      height: scale < 1
                          ? minContentHeight
                          : constraints.maxHeight,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // Avatar
                          Container(
                            width: 96,
                            height: 96,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFDF5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Text(
                              initial,
                              style: EllaFonts.bricolage(
                                const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF444441),
                                ),
                              ),
                            ),
                          ),

                          // Middle section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                const SizedBox(height: 14),

                                // Name
                                Text(
                                  _name,
                                  style: EllaFonts.bricolage(
                                    const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C2C2A),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Age Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAEEDA),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SvgPicture.asset(
                                        '$_asset/balloon.svg',
                                        width: 18,
                                        height: 18,
                                        colorFilter: const ColorFilter.mode(
                                          Color(0xFFEF9F27),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$_age years old',
                                        style: EllaFonts.body(
                                          const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF854F0B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Settings Card
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFDF5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      // Email Row
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFE1F5EE),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.mail_outline_rounded,
                                                color: Color(0xFF0F6E56),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Email',
                                                    style: EllaFonts.body(
                                                      const TextStyle(
                                                        fontSize: 13,
                                                        color: Color(
                                                          0xFF5F5E5A,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _email,
                                                    style: EllaFonts.body(
                                                      const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF2C2C2A,
                                                        ),
                                                      ),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(
                                        height: 1,
                                        color: Color(0xFFEDE7D6),
                                      ),
                                      // Sound Effects Row
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFFBEAF0),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.volume_up_rounded,
                                                color: Color(0xFFD4537E),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Sound effects',
                                                    style: EllaFonts.body(
                                                      const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF2C2C2A,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Music and tap sounds',
                                                    style: EllaFonts.body(
                                                      const TextStyle(
                                                        fontSize: 13,
                                                        color: Color(
                                                          0xFF5F5E5A,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            // Custom Switch
                                            GestureDetector(
                                              onTap: () {
                                                final newVal = !_sfxOn;
                                                setState(() {
                                                  _sfxOn = newVal;
                                                });
                                                ref
                                                    .read(audioProvider)
                                                    .setSfxEnabled(newVal);
                                                ref
                                                    .read(audioProvider)
                                                    .setMusicEnabled(newVal);
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                width: 52,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: _sfxOn
                                                      ? const Color(0xFFD4537E)
                                                      : const Color(0xFFB4B2A9),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    AnimatedPositioned(
                                                      duration: const Duration(
                                                        milliseconds: 180,
                                                      ),
                                                      left: _sfxOn ? 25 : 3,
                                                      child: Container(
                                                        width: 24,
                                                        height: 24,
                                                        decoration:
                                                            const BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 24),

                          // Sign out button
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _handleSignOut,
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: EllaColors.errorLight,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: EllaColors.errorDark,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: EllaColors.berryDeep,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    '$_asset/sign-out.svg',
                                    width: 24,
                                    height: 24,
                                    colorFilter: const ColorFilter.mode(
                                      EllaColors.errorDark,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sign Out',
                                    style: EllaFonts.body(
                                      const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: EllaColors.errorDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Delete account
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _handleDeleteAccount,
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: EllaColors.errorDark,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Delete Account',
                                style: EllaFonts.body(
                                  const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: EllaColors.errorDark,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Privacy Policy & Contact Us
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed('/privacy-policy');
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      '$_asset/keyhole.svg',
                                      width: 24,
                                      height: 24,
                                      colorFilter: const ColorFilter.mode(
                                        EllaColors.ink,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Privacy Policy',
                                      style: EllaFonts.body(
                                        const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: EllaColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              InkWell(
                                onTap: () {},
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      '$_asset/address-book.svg',
                                      width: 24,
                                      height: 24,
                                      colorFilter: const ColorFilter.mode(
                                        EllaColors.ink,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Contact Us',
                                      style: EllaFonts.body(
                                        const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: EllaColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          if (_appVersion.isNotEmpty)
                            Text(
                              _appVersion,
                              style: EllaFonts.body(
                                const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: EllaColors.ink,
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                    if (scale >= 1) {
                      return content;
                    }
                    return FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      child: content,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
