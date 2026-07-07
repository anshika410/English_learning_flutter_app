// Splash — Figma "Onboarding / Splash Screen": the shared onboarding scenery
// (peach→cyan sky, hills, garden blooms) with the live listening Zoe mascot
// (same native animation as the Home screen) and the ZoSpeak wordmark.
// Routes to /home or /login once the auth check completes.

import 'package:flutter/material.dart';

import '../core/text_styles.dart';
import '../core/theme_colors.dart';
import '../services/ella_api_service.dart';
import '../services/update_service.dart';
import 'child_view/widgets/onboarding_scenery.dart';
import 'child_view/widgets/zoe_mascot.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Artificial delay for splash screen aesthetics
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check for in-app updates (Android only)
    await UpdateService.checkForUpdates();

    if (!mounted) return;

    final api = EllaApiService();
    final isAuthenticated = await api.isAuthenticated();

    if (!mounted) return;

    if (isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAFA),
      body: OnboardingScenery(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Same listening mascot animation as the Home screen.
              ZoeMascot(
                mode: ZoeMascotMode.listening,
                size: 160,
                reducedMotion: MediaQuery.of(context).disableAnimations,
              ),
              const SizedBox(height: 24),
              Text(
                'ZoSpeak',
                style: EllaFonts.bricolage(
                  const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: EllaColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Talk More. Grow Your English',
                style: EllaTextStyles.bodySemibold.copyWith(height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
