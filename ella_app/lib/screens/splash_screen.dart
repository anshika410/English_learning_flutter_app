// Splash — Figma "Onboarding / Splash Screen": the shared onboarding scenery
// (peach→cyan sky, hills, garden blooms) with the live listening Zoe mascot
// (same native animation as the Home screen).
// Routes to /home or /login once the auth check completes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../providers/onboarding_provider.dart';

import '../services/ella_api_service.dart';
import '../services/update_service.dart';
import 'child_view/widgets/onboarding_scenery.dart';
import 'child_view/widgets/zoe_mascot.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Removed artificial delay for faster loading

    if (!mounted) return;

    // Check for in-app updates (Android only)
    await UpdateService.checkForUpdates();

    if (!mounted) return;

    final api = EllaApiService();
    final isAuthenticated = await api.isAuthenticated();

    if (!mounted) return;

    if (isAuthenticated) {
      try {
        await ref.read(chatProvider.future);
        await ref.read(onboardingProvider.future);
      } catch (_) {
        // If it fails, RootGate will show error or reload
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashUI();
  }
}

class SplashUI extends StatelessWidget {
  const SplashUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAFA),
      body: OnboardingScenery(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortestSide = constraints.biggest.shortestSide;
            final mascotSize = (shortestSide * 0.42).clamp(136.0, 180.0);

            return Center(
              child: ZoeMascot(
                mode: ZoeMascotMode.listening,
                size: mascotSize,
                reducedMotion: MediaQuery.of(context).disableAnimations,
              ),
            );
          },
        ),
      ),
    );
  }
}
