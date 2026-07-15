// Botanical Berry button — flat-fill spec (Botanical Berry Design System,
// July 2026). Flat berry/green fill, 2px dark stroke, a single 3px flat "stamp"
// shadow (no blur), pill radius. No gradient, no gloss overlay. On press the
// button drops translateY(3) and the stamp collapses to zero for tactile feel.
//
// Variants:
//   • primary   — berryMain fill, berryDark stroke + shadow, onPrimary label.
//   • secondary — greenMain fill, greenDark stroke + shadow, ink label.
//   • outline   — surface fill, berryDeep stroke + shadow, berryDark label
//                 (login "Continue With Email" per the onboarding Figma).
//
// A11y open item: onPrimary on berryMain = 3.55:1 (below AA 4.5:1 at 18px). This
// matches the reference design; if flagged on-device, switch the primary fill to
// berryDark (5.92:1) without touching any other token.
// See EllaIconButton (below) for the round mic/action button.

import 'package:flutter/material.dart';

import '../../../core/ella_smooth_shape.dart';
import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../services/audio_service.dart';

enum EllaButtonVariant { primary, secondary, outline }

class EllaPrimaryButton extends StatefulWidget {
  final String label;
  final Widget? labelChild;
  final VoidCallback? onTap;
  final double height;
  final bool uppercase;
  final BorderRadius borderRadius;
  final EllaButtonVariant variant;
  final double horizontalPadding;
  final double leadingGap;

  /// Optional leading glyph rendered before the label (e.g. the voice icon on
  /// the home "Let's Talk" CTA). Callers tint it to match [_labelColor].
  final Widget? leading;
  final bool playTapClickSound;
  final Color? backgroundColor;
  final Color? edgeColor;

  const EllaPrimaryButton({
    super.key,
    required this.label,
    this.labelChild,
    this.onTap,
    this.height = 52,
    this.uppercase = false,
    this.variant = EllaButtonVariant.primary,
    this.leading,
    this.horizontalPadding = 18,
    this.leadingGap = 10,
    // Pill by default, per the flat-fill button spec.
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.playTapClickSound = true,
    this.backgroundColor,
    this.edgeColor,
  });

  @override
  State<EllaPrimaryButton> createState() => _EllaPrimaryButtonState();
}

class _EllaPrimaryButtonState extends State<EllaPrimaryButton> {
  bool _pressed = false;

  bool get _isPrimary => widget.variant == EllaButtonVariant.primary;
  bool get _isOutline => widget.variant == EllaButtonVariant.outline;

  Color get _fill => widget.backgroundColor ?? switch (widget.variant) {
    EllaButtonVariant.primary => EllaColors.berryMain,
    EllaButtonVariant.secondary => EllaColors.greenMain,
    EllaButtonVariant.outline => EllaColors.surface,
  };
  // Primary berry edge is berryDeep #7B163C at 3px (matches the mic button);
  // secondary green keeps its greenDark 2px edge. Outline shares the berryDeep
  // edge so the two login CTAs read as one family.
  Color get _edge =>
      widget.edgeColor ?? (_isPrimary || _isOutline ? EllaColors.berryDeep : EllaColors.greenDark);
  double get _edgeWidth => _isPrimary || _isOutline ? 3 : 2;
  Color get _labelColor => switch (widget.variant) {
    EllaButtonVariant.primary => EllaColors.onPrimary,
    EllaButtonVariant.secondary => EllaColors.ink,
    EllaButtonVariant.outline => EllaColors.berryDark,
  };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final translateY = _pressed ? 3.0 : 0.0;
    final boxShadow = (_pressed || !enabled)
        ? const <BoxShadow>[]
        : [BoxShadow(color: _edge, offset: const Offset(0, 3), blurRadius: 0)];

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              if (widget.playTapClickSound) {
                playTapClick();
              }
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.ease,
        transform: Matrix4.translationValues(0, translateY, 0),
        width: double.infinity,
        height: widget.height,
        decoration: ellaSmoothDecoration(
          color: enabled ? _fill : _fill.withValues(alpha: 0.5),
          borderRadius: widget.borderRadius,
          side: BorderSide(color: _edge, width: _edgeWidth),
          shadows: boxShadow,
        ),
        // Full-width centred row; the label truncates with "…" at full size
        // rather than shrinking to fit.
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                SizedBox(width: widget.leadingGap),
              ],
              Flexible(
                child: widget.labelChild ??
                    Text(
                      widget.uppercase ? widget.label.toUpperCase() : widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: EllaTextStyles.button.copyWith(
                        color: _labelColor,
                        height: 1.15,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon-only flat button — a fully round berry (or green) circle for mic/action
/// moments. Same flat treatment as [EllaPrimaryButton]: 2px stroke + 3px stamp,
/// no gloss. Icon is onPrimary on berry; ink on green (onPrimary fails AA there).
class EllaIconButton extends StatefulWidget {
  final IconData? icon;

  /// Custom glyph rendered in place of [icon] (e.g. an exported Figma SVG such
  /// as the paper-plane send icon). Provide exactly one of [icon] / [glyph].
  final Widget? glyph;
  final VoidCallback? onTap;
  final double size;

  /// When true the fill uses greenMain instead of berryMain.
  final bool secondary;

  final bool playTapClickSound;

  const EllaIconButton({
    super.key,
    this.icon,
    this.glyph,
    this.onTap,
    this.size = 60,
    this.secondary = false,
    this.playTapClickSound = true,
  }) : assert(
         icon != null || glyph != null,
         'EllaIconButton needs an icon or a glyph',
       );

  @override
  State<EllaIconButton> createState() => _EllaIconButtonState();
}

class _EllaIconButtonState extends State<EllaIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final fill = widget.secondary ? EllaColors.greenMain : EllaColors.berryMain;
    final edge = widget.secondary ? EllaColors.greenDark : EllaColors.berryDark;
    final iconColor = widget.secondary ? EllaColors.ink : EllaColors.onPrimary;
    final boxShadow = (_pressed || !enabled)
        ? const <BoxShadow>[]
        : [BoxShadow(color: edge, offset: const Offset(0, 3), blurRadius: 0)];

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              if (widget.playTapClickSound) {
                playTapClick();
              }
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.ease,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: enabled ? fill : fill.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: edge, width: 2),
          boxShadow: boxShadow,
        ),
        child: Center(
          child:
              widget.glyph ??
              Icon(widget.icon, size: widget.size * 0.5, color: iconColor),
        ),
      ),
    );
  }
}
