// Botanical Berry typography — the app's single source of text styles.
// See Botanical_Berry_Design_System.md. Fonts load at runtime via google_fonts
// (no bundled .ttf): Bricolage Grotesque (display/UI), Andika (body + button
// labels), Grandstander (Zoe voice, 400 only), Baloo 2 (Hindi fallback).
//
// Role rules (baked into the styles below):
//   • Andika       → child-read copy + button labels (literacy-optimised).
//   • Bricolage    → titles, tabs, chips, metadata (structural UI to navigate).
//   • Grandstander → Zoe's voice, weight 400 ONLY (never bolded — heavier weights
//                    read as authoritative and break Zoe's coaching register).

import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_colors.dart';

/// Font-family helpers. Prefer the ready-made styles in [EllaTextStyles]; reach
/// for these only when composing a bespoke style.
abstract final class EllaFonts {
  static TextStyle bricolage([TextStyle? style]) =>
      GoogleFonts.bricolageGrotesque(textStyle: style);
  static TextStyle body([TextStyle? style]) =>
      GoogleFonts.andika(textStyle: style);
  static TextStyle zoe([TextStyle? style]) =>
      GoogleFonts.grandstander(textStyle: style);
  static TextStyle hindi([TextStyle? style]) =>
      GoogleFonts.baloo2(textStyle: style);
}

/// The mobile type scale from the Botanical Berry spec. Base 16, minimum 12.
/// Default colour is [EllaColors.ink]; letter-spacing 0 unless noted.
abstract final class EllaTextStyles {
  static const _ink = EllaColors.ink;

  // ── Metadata / labels — Bricolage ─────────────────────────────────────
  /// 12 / Bricolage 600 — metadata, compact labels, helper captions (minimum).
  static TextStyle get caption => EllaFonts.bricolage(
    const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _ink,
      letterSpacing: 0,
    ),
  );

  // ── Body — Andika ─────────────────────────────────────────────────────
  /// 14 / Andika 400 — secondary copy, short supporting text.
  static TextStyle get bodySmall => EllaFonts.body(
    const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: _ink),
  );

  /// 16 / Andika 400 — default learner-facing text.
  static TextStyle get bodyBase => EllaFonts.body(
    const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: _ink),
  );

  /// 18 / Andika 400 — important body copy, readable chat text.
  static TextStyle get bodyLarge => EllaFonts.body(
    const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: _ink),
  );

  // ── Titles / display — Bricolage ──────────────────────────────────────
  /// 20 / Bricolage 700 — card titles, section headings.
  static TextStyle get titleSmall => EllaFonts.bricolage(
    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink),
  );

  /// 24 / Bricolage 700 — screen titles, modal titles.
  static TextStyle get titleMedium => EllaFonts.bricolage(
    const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _ink),
  );

  /// 32 / Bricolage 800 — major screen heading, empty-state headline.
  static TextStyle get headline => EllaFonts.bricolage(
    const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _ink),
  );

  /// 40 / Bricolage 800 — rare hero / celebration display.
  static TextStyle get display => EllaFonts.bricolage(
    const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: _ink),
  );

  // ── Action / voice ────────────────────────────────────────────────────
  /// 18 / Andika 700 — primary and secondary button labels.
  static TextStyle get button => EllaFonts.body(
    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
  );

  /// 18 / Grandstander 400 — Zoe bubbles and coaching prompts. Never bold.
  static TextStyle get zoeVoice => EllaFonts.zoe(
    const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: _ink),
  );
}
