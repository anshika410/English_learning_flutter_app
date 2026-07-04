// Botanical Berry design system — colour tokens.
// See Botanical_Berry_Design_System.md. Pure colour constants — no Flutter
// widgets. Berry = action, green = growth, environment = atmosphere.
//
// Accessibility note: `berryMain` is DECORATIVE ONLY — white text on it fails
// WCAG AA (3.55:1). The AA-safe interactive fill is `berryDark` (5.92:1 with
// onPrimary). Never place a label directly on `berryMain` or `greenDark`.

import 'package:flutter/painting.dart';

/// Botanical Berry colour tokens for the ELLA app.
abstract final class EllaColors {
  // ── Neutrals / surface ──────────────────────────────────────────────
  static const canvas = Color(0xFFF7FCFB); // app background, root scaffold
  static const surface = Color(0xFFFFFDF4); // default cards, panels, composer
  static const surfaceVariant = Color(0xFFF1FFF8); // grouped/garden-adjacent
  static const surfaceElevated = Color(0xFFFFFAF0); // dialogs, floating cards
  static const border = Color(0xFFD5E7DF); // default borders / dividers
  static const borderStrong = Color(0xFF9DB8AE); // focused inputs, selections

  // ── Text ────────────────────────────────────────────────────────────
  static const ink = Color(0xFF28362F); // primary text on light surfaces
  static const textSecondary = Color(0xFF5B7067); // supporting copy
  static const textTertiary = Color(0xFF80948C); // metadata, timestamps
  static const textDisabled = Color(0xFFB7C9C1); // disabled controls
  static const onPrimary = Color(0xFFFFFCF7); // text/icons on Berry/green fills
  static const onDark = Color(0xFFF7FCFB); // text/icons on deep scrims

  // ── Botanical Berry / primary ───────────────────────────────────────
  static const berryLight = Color(0xFFFFD9E8); // soft action surfaces, chips
  static const berryMain = Color(0xFFE84A8A); // DECORATIVE brand fill only
  static const berryDark = Color(0xFFB92261); // AA-safe interactive fill, press
  static const berryDeep = Color(0xFF7B163C); // text on berry-tinted surfaces

  // ── Green / accent ──────────────────────────────────────────────────
  static const greenLight = Color(0xFFDDF8E8); // growth cards, garden hints
  static const greenMain = Color(0xFF71D99B); // greenhouse accent, secondary
  static const greenDark = Color(0xFF2F9A55); // active garden action, leaves
  static const greenDeep = Color(0xFF185E35); // dark green text, borders

  // ── Environment / sky ───────────────────────────────────────────────
  static const environmentLight = Color(
    0xFFEAFDFF,
  ); // sky tint, glass highlight
  static const environmentMain = Color(0xFFD9FAFF); // screen air, chat backdrop
  static const environmentDark = Color(0xFF9CDCE8); // sky shadows, glass edges
  static const environmentDeep = Color(0xFF4C8290); // text on environment fills

  // ── Garden greens ───────────────────────────────────────────────────
  static const fieldLight = Color(0xFFD7F2C4); // far field, grass planes
  static const fieldMain = Color(0xFF8DD67C); // main ground plane
  static const fieldDark = Color(0xFF4E9A45); // ground depth, hill shadow
  static const leaf = Color(0xFF4EB96E); // leaves, small garden icons
  static const stem = Color(0xFF2F9A55); // plant stems
  static const moss = Color(0xFF6EAE48); // progress bars, utility actions
  static const soil = Color(0xFF9A6A44); // soil, pot edges

  // ── Semantics ───────────────────────────────────────────────────────
  static const errorLight = Color(0xFFFFE8EE);
  static const error = Color(0xFFE0103C);
  static const errorDark = Color(0xFFA50B2E);
  static const warningLight = Color(0xFFFFF3D4);
  static const warning = Color(0xFFFFAA00);
  static const warningDark = Color(0xFFB86D00);
  static const successLight = Color(0xFFE8F8EF);
  static const success = Color(0xFF2F9A55);
  static const successDark = Color(0xFF185E35);
  static const infoLight = Color(0xFFE8F4FF);
  static const info = Color(0xFF5898E0);
  static const infoDark = Color(0xFF1A3870);

  // ── Back-compat aliases ─────────────────────────────────────────────
  // Old EllaColors names mapped onto Botanical Berry roles so unmigrated call
  // sites keep compiling. Prefer the canonical tokens above in new code.
  static const bg = canvas;
  static const muted = textTertiary;
  static const secondary = textSecondary;
  static const primary = ink;
  static const bubbleSurface = surface;
}

/// Botanical Berry gradient stops. Each has a documented solid fallback for
/// dense/repeated UI — do not use gradients as default card backgrounds.
abstract final class BotanicalBerryGradients {
  /// Primary CTA highlight, mic active state. Fallback: [EllaColors.berryDark].
  static const berry = <Color>[
    Color(0xFFFF8EB8),
    Color(0xFFE84A8A),
    Color(0xFFB92261),
  ];
  static const berryStops = <double>[0.0, 0.55, 1.0];

  /// Growth celebration, active garden action. Fallback: [EllaColors.greenMain].
  static const green = <Color>[
    Color(0xFFA8F0C6),
    Color(0xFF71D99B),
    Color(0xFF2F9A55),
  ];

  /// Screen background, greenhouse glass. Fallback: [EllaColors.environmentMain].
  static const environment = <Color>[
    Color(0xFFF7FFFF),
    Color(0xFFD9FAFF),
    Color(0xFFF1FFF8),
  ];

  /// Elevated cards, calm onboarding. Fallback: [EllaColors.surface].
  static const surface = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFFFFDF4),
    Color(0xFFF1FFF8),
  ];

  /// Garden field and ground depth. Fallback: [EllaColors.fieldMain].
  static const gardenField = <Color>[
    Color(0xFFD7F2C4),
    Color(0xFF8DD67C),
    Color(0xFF4E9A45),
  ];

  /// Level-up and bloom moments. Fallback: [EllaColors.berryLight].
  static const celebration = <Color>[
    Color(0xFFEAFDFF),
    Color(0xFFFFD9E8),
    Color(0xFFDDF8E8),
  ];
}

/// Role-aliased colour set for a skill track (Vocabulary / Fluency / Grammar).
/// `main` is for blooms/badges/accent bars; `text` is readable on `surface`.
class TrackColors {
  const TrackColors({
    required this.surface,
    required this.border,
    required this.main,
    required this.text,
  });

  final Color surface;
  final Color border;
  final Color main;
  final Color text;

  /// Vocabulary — rose identity.
  static const vocabulary = TrackColors(
    surface: Color(0xFFFFF0F3),
    border: Color(0xFFF0C0CC),
    main: Color(0xFFD4708A),
    text: Color(0xFF6E3040),
  );

  /// Fluency — violet identity.
  static const fluency = TrackColors(
    surface: Color(0xFFF5F0FF),
    border: Color(0xFFD8CCF0),
    main: Color(0xFF9478D0),
    text: Color(0xFF3E2870),
  );

  /// Grammar — blue identity.
  static const grammar = TrackColors(
    surface: Color(0xFFE8F4FF),
    border: Color(0xFFB8DCFF),
    main: Color(0xFF5898E0),
    text: Color(0xFF1A3870),
  );
}
