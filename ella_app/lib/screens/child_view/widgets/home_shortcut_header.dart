// Shared Garden / Profile shortcut row used by both home experiences.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/text_styles.dart';
import '../../../core/theme_colors.dart';
import 'circle_icon_button.dart';

const String _kNavGarden = 'assets/homescreen/new/nav-garden.svg';
const String _kNavProfile = 'assets/homescreen/new/nav-profile.svg';

class HomeShortcutHeader extends StatelessWidget {
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenGarden;

  const HomeShortcutHeader({
    super.key,
    required this.onOpenProfile,
    required this.onOpenGarden,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('home-shortcut-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        EllaCircleIconButton(
          key: const ValueKey('home-garden-shortcut'),
          glyph: _SwayingGlyph(
            child: SvgPicture.asset(_kNavGarden, width: 56, height: 56),
          ),
          diameter: 72,
          fill: EllaColors.greenLight,
          ring: EllaColors.greenDark,
          label: 'Garden',
          labelColor: EllaColors.greenDeep,
          labelStyle: EllaTextStyles.buttonSmall,
          labelAsChip: true,
          chipFill: EllaColors.greenLight,
          chipBorder: EllaColors.greenDark,
          onTap: onOpenGarden,
        ),
        EllaCircleIconButton(
          key: const ValueKey('home-profile-shortcut'),
          glyph: SvgPicture.asset(_kNavProfile, width: 56, height: 56),
          diameter: 72,
          fill: EllaColors.surfaceVariant,
          ring: EllaColors.info,
          label: 'Profile',
          labelColor: EllaColors.infoDark,
          labelStyle: EllaTextStyles.buttonSmall,
          labelAsChip: true,
          chipFill: EllaColors.surfaceVariant,
          chipBorder: EllaColors.info,
          onTap: onOpenProfile,
        ),
      ],
    );
  }
}

class _SwayingGlyph extends StatefulWidget {
  final Widget child;

  const _SwayingGlyph({required this.child});

  @override
  State<_SwayingGlyph> createState() => _SwayingGlyphState();
}

class _SwayingGlyphState extends State<_SwayingGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final Animation<double> _angle = Tween<double>(
    begin: -0.06,
    end: 0.06,
  ).animate(CurvedAnimation(parent: _sway, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _sway.stop();
      _sway.value = 0.5;
    } else if (!_sway.isAnimating) {
      _sway.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _angle,
      builder: (context, child) => Transform.rotate(
        angle: _angle.value,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: widget.child,
    );
  }
}
