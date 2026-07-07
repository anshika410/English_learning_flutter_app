import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_colors.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/chat_provider.dart';
import '../../services/ella_api_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'widgets/onboarding_scenery.dart';
import 'widgets/edit_profile_dialog.dart';
import 'widgets/circle_icon_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late bool _musicOn;
  late bool _sfxOn;
  
  bool _isLoading = true;
  String _name = '';
  int _age = 0;

  String _appVersion = '';

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
  
  Future<void> _handleDeleteMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Memory?'),
        content: const Text('Are you sure you want to delete all learning memory? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      if (mounted) setState(() => _isLoading = true);
      try {
        await EllaApiService().resetUserMemory();
        if (!context.mounted) return;
        
        // Clear local memory (onboarding details & auth token)
        await ref.read(onboardingProvider.notifier).reset();
        
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory deleted successfully.')),
        );
        
        // Invalidate the chat provider so RootGate sees the fresh memory state
        ref.invalidate(chatProvider);

        // Force a restart of the app flow
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
      return const Scaffold(
        backgroundColor: EllaColors.canvas,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: EllaColors.canvas,
      body: OnboardingScenery(
        child: Stack(
          children: [
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: EllaColors.surface,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 22,
                            color: EllaColors.ink,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final updated = await EditProfileDialog.show(context, _name, _age);
                          if (updated == true) {
                            setState(() => _isLoading = true);
                            _loadProfile();
                          }
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Profile'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: EllaColors.berryMain,
                          side: const BorderSide(color: EllaColors.berryMain, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        // Avatar
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFFDF5),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A2B),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        // Name
                        Text(
                          _name,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E3A2B),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        // Age Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wb_sunny, color: Color(0xFFE89A00), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Age $_age',
                                style: const TextStyle(
                                  color: Color(0xFFD67300),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 48),
                        
                        // Settings Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFDF5),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: EllaColors.berryMain,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.volume_up, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Sound Effects',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Music & Tap Sounds',
                                          style: TextStyle(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _sfxOn,
                                    activeTrackColor: EllaColors.berryMain,
                                    onChanged: (v) {
                                      setState(() {
                                        _sfxOn = v;
                                        _musicOn = v;
                                      });
                                      ref.read(audioProvider).setSfxEnabled(v);
                                      ref.read(audioProvider).setMusicEnabled(v);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 64),
                        
                        // Sign Out Button
                        OutlinedButton.icon(
                          onPressed: () async {
                            await EllaApiService().logout();
                            try {
                              await GoogleSignIn.instance.signOut();
                            } catch (_) {}
                            // Drop the previous user's cached memory + profile so
                            // the next sign-in rebuilds them from /users/me.
                            ref.invalidate(onboardingProvider);
                            ref.invalidate(chatProvider);
                            if (context.mounted) {
                              Navigator.of(context, rootNavigator: true)
                                  .pushNamedAndRemoveUntil('/login', (route) => false);
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: EllaColors.berryMain,
                            side: const BorderSide(color: EllaColors.berryMain, width: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Delete Memory
                        TextButton(
                          onPressed: _handleDeleteMemory,
                          child: const Text(
                            'Delete Memory',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 64),
                        
                        // Footer
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pushNamed('/privacy-policy');
                                },
                                icon: const Icon(Icons.privacy_tip, color: Color(0xFF1E3A2B), size: 18),
                                label: const Text(
                                  'Privacy Policy',
                                  style: TextStyle(
                                    color: Color(0xFF1E3A2B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.contact_support, color: Color(0xFF1E3A2B), size: 18),
                                label: const Text(
                                  'Contact Us',
                                  style: TextStyle(
                                    color: Color(0xFF1E3A2B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_appVersion.isNotEmpty)
                          Padding(
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
    );
  }
}
