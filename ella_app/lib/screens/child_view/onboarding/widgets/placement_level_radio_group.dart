import 'package:flutter/material.dart';
import '../../../../core/ella_smooth_shape.dart';
import '../../../../core/text_styles.dart';
import '../../../../core/theme_colors.dart';
import '../../../../services/audio_service.dart';

class PlacementLevelRadioGroup extends StatelessWidget {
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  static const List<String> options = [
    'I am starting new',
    'I know some English',
    'I can have short conversations',
    'I can explain my ideas',
    'I am comfortable speaking English',
  ];

  const PlacementLevelRadioGroup({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _OptionCard(
            text: options[i],
            isSelected: selectedIndex == i,
            onTap: () {
              playTapClick();
              onSelect(i);
            },
          ),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selected state matching Figma: blue border (EllaColors.info #5898E0), white background
    final borderColor = isSelected ? EllaColors.info : const Color(0xFFE0EFE7);
    final borderWidth = isSelected ? 2.5 : 1.2;

    final textStyle = EllaFonts.body(
      TextStyle(
        fontSize: 16,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        height: 1.5,
        letterSpacing: 0,
        color: EllaColors.ink,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: ellaSmoothDecoration(
          color: EllaColors.surface,
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: borderWidth),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: textStyle,
              ),
            ),
            const SizedBox(width: 10),
            // Right radio icon:
            // Selected: solid pink circle with white checkmark
            // Unselected: thin circle matching textSecondary color
            isSelected
                ? Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: EllaColors.berryMain,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  )
                : Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: EllaColors.textTertiary,
                        width: 1.5,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
