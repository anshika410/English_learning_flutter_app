import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ella_theme.dart';
import '../widgets/ella_primary_button.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final String level;
  final String levelName;

  const ResultScreen({
    super.key,
    required this.level,
    required this.levelName,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _successCtrl;
  late Animation<double> _successScale;
  late Animation<double> _successOpacity;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _successScale = Tween<double>(begin: 1.0, end: 1.7).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.easeOut),
    );
    _successOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.easeOut),
    );
    // Single success burst on mount
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _successCtrl.forward();
    });
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    super.dispose();
  }

  void _goToMainApp() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.limeLightest,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 56),
            // Avatar (no circle/background) with success pulse ring burst
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _successCtrl,
                    builder: (ctx, child) => Transform.scale(
                      scale: _successScale.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: EllaColors.limeMain
                                .withValues(alpha: _successOpacity.value),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Image.asset(
                      'images/ella-neutral.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // "Great job!" heading
            Text(
              'Great job! 🎉',
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: EllaColors.neutralPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "You're at level",
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: EllaColors.neutralSecondary,
              ),
            ),
            const SizedBox(height: 14),
            // Level badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: EllaColors.mangoMain,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: EllaColors.mangoDark,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                '${widget.level} — ${widget.levelName}',
                style: GoogleFonts.fredoka(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Highlight card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: EllaColors.neutralBorder,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: EllaColors.mangoMain,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'HIGHLIGHT',
                          style: GoogleFonts.inconsolata(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: EllaColors.mangoDark,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You expressed yourself clearly and used good vocabulary when describing your favourite place. Keep it up!',
                      style: GoogleFonts.kalam(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: EllaColors.neutralPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: EllaPrimaryButton(
                label: "Let's Start Learning",
                onTap: _goToMainApp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
