// Profile tab — placeholder. Fleshed out in a later phase.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EllaColors.bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/bottom_tab/profile-svgrepo-com.svg',
                width: 56,
                colorFilter: const ColorFilter.mode(
                    EllaColors.muted, BlendMode.srcIn),
              ),
              const SizedBox(height: 12),
              const Text(
                'Profile',
                style: TextStyle(
                  fontFamily: 'Chillax',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: EllaColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Coming soon',
                style: TextStyle(fontSize: 14, color: EllaColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
