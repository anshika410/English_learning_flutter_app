import 'package:flutter/material.dart';

/// Breakpoint and layout constants for responsive (web/tablet) adaptation.
///
/// All screens are mobile-first. When [isWide] is true (≥ 768px), apply the
/// web-optimised values below. Mobile retains existing hardcoded behaviour.
class EllaResponsive {
  EllaResponsive._();

  /// Returns true when the viewport is wide enough for the web/tablet layout.
  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768;

  // ── Mascot ──────────────────────────────────────────────────────────────
  static const double mascotSizeMobile = 160;
  static const double mascotSizeWide = 240;

  static double mascotSize(BuildContext context) =>
      isWide(context) ? mascotSizeWide : mascotSizeMobile;

  // ── Corner block offsets (how far each block sticks out from its corner) ─
  static const double blockXOffsetMobile = 88;
  static const double blockXOffsetWide = 140;

  static const double blockYOffsetTopMobile = 96;
  static const double blockYOffsetTopWide = 150;

  static const double blockYOffsetBottomMobile = 92;
  static const double blockYOffsetBottomWide = 140;

  // ── Corner block dimensions ─────────────────────────────────────────────
  // Mobile: ~170-180 wide, 340-360 tall (narrow blocks)
  // Wide:   ~240-260 wide, 480-500 tall
  static const double blockWidthNarrowMobile = 170;
  static const double blockWidthNarrowWide = 240;

  static const double blockWidthWideMobile = 180;
  static const double blockWidthWideWide = 260;

  static const double blockHeightTallMobile = 360;
  static const double blockHeightTallWide = 500;

  static const double blockHeightMidMobile = 350;
  static const double blockHeightMidWide = 490;

  static const double blockHeightShortMobile = 340;
  static const double blockHeightShortWide = 480;

  // ── Typography ──────────────────────────────────────────────────────────
  /// Subline / supporting body text (welcome screen)
  static const double sublineFontSizeMobile = 17;
  static const double sublineFontSizeWide = 20;

  static double sublineFontSize(BuildContext context) =>
      isWide(context) ? sublineFontSizeWide : sublineFontSizeMobile;

  /// Onboarding question text (Chillax heading)
  static const double questionFontSizeMobile = 24;
  static const double questionFontSizeWide = 28;

  static double questionFontSize(BuildContext context) =>
      isWide(context) ? questionFontSizeWide : questionFontSizeMobile;

  // ── Button ──────────────────────────────────────────────────────────────
  static const double buttonHeightMobile = 52;
  static const double buttonHeightWide = 56;
  static const double buttonHorizontalPaddingWide = 24;

  static double buttonHeight(BuildContext context) =>
      isWide(context) ? buttonHeightWide : buttonHeightMobile;

  // ── Text field (onboarding) ─────────────────────────────────────────────
  static const double textFieldMaxWidthWide = 480;
  static const double textFieldBorderRadiusMobile = 20;
  static const double textFieldBorderRadiusWide = 8;
  static const double textFieldContentPaddingHorizontalWide = 16;
  static const double textFieldContentPaddingVerticalWide = 18;

  static double textFieldBorderRadius(BuildContext context) =>
      isWide(context) ? textFieldBorderRadiusWide : textFieldBorderRadiusMobile;
}
