// Botanical Berry button — flat-fill spec (Botanical Berry Design System,
// July 2026). Flat berry/green fill, 2px dark stroke, a single 3px flat "stamp"
// shadow (no blur), pill radius. No gradient, no gloss overlay. On press the
// button drops translateY(3) and the stamp collapses to zero for tactile feel.
//
// Variants:
//   • primary   — berryMain fill, berryDark stroke + shadow, onPrimary label.
//   • secondary — greenMain fill, greenDark stroke + shadow, ink label.
//
// A11y open item: onPrimary on berryMain = 3.55:1 (below AA 4.5:1 at 18px). This
// matches the reference design; if flagged on-device, switch the primary fill to
// berryDark (5.92:1) without touching any other token.
// See EllaIconButton (below) for the round mic/action button.

import 'package:flutter/material.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import '../../../services/audio_service.dart';

enum EllaButtonVariant { primary, secondary }

class EllaPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final bool uppercase;
  final BorderRadius borderRadius;
  final EllaButtonVariant variant;

  /// Optional leading glyph rendered before the label (e.g. the voice icon on
  /// the home "Let's Talk" CTA). Callers tint it to match [_labelColor].
  final Widget? leading;

  const EllaPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
    this.uppercase = false,
    this.variant = EllaButtonVariant.primary,
    this.leading,
    // Pill by default, per the flat-fill button spec.
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  @override
  State<EllaPrimaryButton> createState() => _EllaPrimaryButtonState();
}

class _EllaPrimaryButtonState extends State<EllaPrimaryButton> {
  bool _pressed = false;

  bool get _isPrimary => widget.variant == EllaButtonVariant.primary;

  Color get _fill => _isPrimary ? EllaColors.berryMain : EllaColors.greenMain;
  // Primary berry edge is berryDeep #7B163C at 3px (matches the mic button);
  // secondary green keeps its greenDark 2px edge.
  Color get _edge => _isPrimary ? EllaColors.berryDeep : EllaColors.greenDark;
  double get _edgeWidth => _isPrimary ? 3 : 2;
  Color get _labelColor => _isPrimary ? EllaColors.onPrimary : EllaColors.ink;

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
              playTapClick();
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
        decoration: BoxDecoration(
          color: enabled ? _fill : _fill.withValues(alpha: 0.5),
          borderRadius: widget.borderRadius,
          border: Border.all(color: _edge, width: _edgeWidth),
          boxShadow: boxShadow,
        ),
        // Full-width centred row; the label truncates with "…" at full size
        // rather than shrinking to fit.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  widget.uppercase ? widget.label.toUpperCase() : widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EllaTextStyles.button.copyWith(color: _labelColor),
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
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  /// When true the fill uses greenMain instead of berryMain.
  final bool secondary;

  const EllaIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 60,
    this.secondary = false,
  });

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
              playTapClick();
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
          child: Icon(widget.icon, size: widget.size * 0.5, color: iconColor),
        ),
      ),
    );
  }
}
