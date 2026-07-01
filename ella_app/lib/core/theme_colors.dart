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

  // Grape — Grammar strand
  static const grapeLightest = Color(0xFFF5F0FF);
  static const grapeMain = Color(0xFF8B5CF6);
  static const grapeDark = Color(0xFF6030C8);

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

  // Room — warm "lamp-lit room" backdrop for Home + Session screens.
  // Estimated from the Figma screenshot; tweak to taste for an exact match.
  static const roomWallTop = Color(0xFFC8A87C); // light tan upper wall
  static const roomWallBottom = Color(0xFF5E3B1E); // dark brown lower wall/floor
  static const avatarRing = Color(0xFF4A3322); // thick deep-brown mascot ring
  static const bubbleSurface = Color(0xFFFBF6EE); // cream speech bubble
  static const lampGlow = Color(0x66FFB020); // warm glow behind the bulb
  static const bubbleText = Color(0xFF333333); // greeting / caption body text
  static const navBorder = Color(0xFFA7D4F5); // light-blue bottom-nav outline
  static const navSelected = Color(0xFFEBDFC9); // tan highlight behind active tab
}
