// Profile tab — placeholder. Fleshed out in a later phase.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EllaColors.canvas,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/bottom_tab/profile-svgrepo-com.svg',
                width: 56,
                colorFilter: const ColorFilter.mode(
                  EllaColors.textTertiary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 12),
              Text('Profile', style: EllaTextStyles.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Coming soon',
                style: EllaTextStyles.bodySmall.copyWith(
                  color: EllaColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
