import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ella_theme.dart';
import '../widgets/ella_primary_button.dart';
import 'placement_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _navigateToPlacement(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context2, animation, secondary) => const PlacementScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context2, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 100),
            // Ella mascot — no circle, floats freely
            Hero(
              tag: 'ella-avatar',
              child: SizedBox(
                width: 200,
                height: 200,
                child: Image.asset(
                  'images/ella-neutral.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Welcome text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "Hi! I'm Ella — your English speaking buddy. Let's find your voice together.",
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: EllaColors.neutralPrimary,
                  height: 1.4,
                ),
              ),
            ),
            const Spacer(),
            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: EllaPrimaryButton(
                label: "Let's Go",
                onTap: () => _navigateToPlacement(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
