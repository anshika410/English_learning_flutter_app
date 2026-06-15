// Palette ported 1:1 from the HTML mockup's CSS :root variables
// (ella-garden-nonlinear.html). Pure colour constants — no Flutter widgets.

import 'package:flutter/painting.dart';

/// ELLA "sticker garden" colour tokens.
abstract final class EllaColors {
  // Mango
  static const mangoLightest = Color(0xFFFFF3E0);
  static const mangoLight = Color(0xFFFFD699);
  static const mangoTop = Color(0xFFFFAA20);
  static const mangoMain = Color(0xFFFF9500);
  static const mangoDark = Color(0xFFC87000);
  static const mangoDeepest = Color(0xFF7A4400);

  // Sky
  static const skyLightest = Color(0xFFE8F4FF);
  static const skyLight = Color(0xFFB8DCFF);
  static const skyMain = Color(0xFF3B9EFF);
  static const skyDark = Color(0xFF1A6CC8);
  static const skyDeepest = Color(0xFF0A3870);

  // Lime
  static const limeLightest = Color(0xFFF0FBE8);
  static const limeLight = Color(0xFFC4F08A);
  static const limeMain = Color(0xFF72CC14);
  static const limeDark = Color(0xFF4E9A00);
  static const limeDeepest = Color(0xFF2A5800);

  // Rose
  static const roseLightest = Color(0xFFFFF0F3);
  static const roseLight = Color(0xFFFFB8C8);
  static const roseMain = Color(0xFFFF4878);
  static const roseDark = Color(0xFFC82050);

  // Zoe mint
  static const zoeMint = Color(0xFF4CAF82);
  static const zoeMintLight = Color(0xFFD4F0E4);

  // Neutrals / surfaces
  static const bg = Color(0xFFFFFDF8);
  static const surface = Color(0xFFFFF7EC);
  static const border = Color(0xFFF0E4CC);
  static const muted = Color(0xFFC0A880);
  static const secondary = Color(0xFF6B5740);
  static const primary = Color(0xFF2C1E0F);
  static const ink = Color(0xFF1A1220);
}
