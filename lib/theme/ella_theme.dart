import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color Tokens ────────────────────────────────────────────────────────────

class EllaColors {
  EllaColors._();

  // Mango — CTAs, mic button, user speech bubbles
  static const mangoLightest = Color(0xFFFFF3E0);
  static const mangoLight = Color(0xFFFFD699);
  static const mangoTop = Color(0xFFFFAA20);
  static const mangoMain = Color(0xFFFF9500);
  static const mangoDark = Color(0xFFC87000);
  static const mangoDeepest = Color(0xFF7A4400);

  // Sky — Ella's voice, conversation, trust
  static const skyLightest = Color(0xFFE8F4FF);
  static const skyLight = Color(0xFFB8DCFF);
  static const skyTop = Color(0xFF55AEFF);
  static const skyMain = Color(0xFF3B9EFF);
  static const skyDark = Color(0xFF1A6CC8);
  static const skyDeepest = Color(0xFF0A3870);

  // Lime — rewards, success, progress
  static const limeLightest = Color(0xFFF0FBE8);
  static const limeLight = Color(0xFFC4F08A);
  static const limeMain = Color(0xFF72CC14);
  static const limeDark = Color(0xFF4E9A00);
  static const limeDeepest = Color(0xFF2A5800);

  // Rose — interests, energy, celebration
  static const roseLightest = Color(0xFFFFF0F3);
  static const roseLight = Color(0xFFFFB8C8);
  static const roseMain = Color(0xFFFF4878);
  static const roseDark = Color(0xFFC82050);

  // Sunny Yellow — welcome screen corner accent
  static const sunnyYellow = Color(0xFFFFD600);

  // Zoe — mascot brand green
  static const zoeMint = Color(0xFF4CAF82); // medium green for borders
  static const zoeMintLight = Color(0xFFD4F0E4); // pale mint for backgrounds

  // Neutral palette
  static const neutralBg = Color(0xFFFFFDF8);
  static const neutralSurface = Color(0xFFFFF7EC);
  static const neutralBorder = Color(0xFFF0E4CC);
  static const neutralMuted = Color(0xFFC0A880);
  static const neutralSecondary = Color(0xFF6B5740);
  static const neutralPrimary = Color(0xFF2C1E0F);

  // Ink — reserved for CTA shadow + avatar ring ONLY
  static const ink = Color(0xFF1A1220);

  // Semantic
  static const error = Color(0xFFE0103C);
  static const warning = Color(0xFFFFAA00);
  static const success = limeMain;
}

// ─── Theme Builder ────────────────────────────────────────────────────────────

class EllaTheme {
  EllaTheme._();

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: EllaColors.mangoMain,
          brightness: Brightness.light,
        ).copyWith(
          primary: EllaColors.mangoMain,
          onPrimary: Colors.white,
          secondary: EllaColors.skyMain,
          onSecondary: Colors.white,
          surface: EllaColors.neutralBg,
          onSurface: EllaColors.neutralPrimary,
          error: EllaColors.error,
        );

    final base = GoogleFonts.baloo2TextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: EllaColors.neutralBg,
      textTheme: base.copyWith(
        displayLarge: base.displayLarge?.copyWith(
          fontFamily: 'Chillax',
          fontWeight: FontWeight.w700,
          color: EllaColors.neutralPrimary,
        ),
        displayMedium: base.displayMedium?.copyWith(
          fontFamily: 'Chillax',
          fontWeight: FontWeight.w600,
          color: EllaColors.neutralPrimary,
        ),
        displaySmall: base.displaySmall?.copyWith(
          fontFamily: 'Chillax',
          fontWeight: FontWeight.w600,
          color: EllaColors.neutralPrimary,
        ),
        headlineLarge: base.headlineLarge?.copyWith(
          fontFamily: 'Chillax',
          fontWeight: FontWeight.w600,
          color: EllaColors.neutralPrimary,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontFamily: 'Chillax',
          fontWeight: FontWeight.w600,
          color: EllaColors.neutralPrimary,
        ),
        bodyLarge: base.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: EllaColors.neutralPrimary,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: EllaColors.neutralPrimary,
        ),
        labelLarge: base.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: EllaColors.neutralPrimary,
        ),
      ),
    );
  }
}
