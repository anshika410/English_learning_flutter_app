import 'package:flutter/material.dart';
import '../../../../core/theme_colors.dart';

class PlacementTopProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0

  const PlacementTopProgressBar({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F0E8),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: EllaColors.greenDark,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
