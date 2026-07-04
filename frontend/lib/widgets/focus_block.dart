import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/focus_options.dart';
import '../theme/ella_theme.dart';

/// Generic focus-area chip selector block.
/// Used in both FocusDiscoveryScreen and the in-conversation Focus Areas panel.
class FocusBlock<T extends Enum> extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;

  const FocusBlock({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  String _labelFor(T v) {
    if (v is GrammarFocus) return v.label;
    if (v is VocabFocus) return v.label;
    if (v is FluencyFocus) return v.label;
    return v.name;
  }

  String _descriptionFor(T v) {
    if (v is GrammarFocus) return v.description;
    if (v is VocabFocus) return v.description;
    if (v is FluencyFocus) return v.description;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.neutralPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: EllaColors.neutralMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Chip row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: values.map((v) {
              final isSelected = v == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? EllaColors.mangoLightest
                          : Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isSelected
                            ? EllaColors.mangoDark
                            : EllaColors.neutralBorder,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? EllaColors.mangoDark
                              : EllaColors.neutralBorder,
                          offset: const Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      _labelFor(v),
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? EllaColors.mangoDeepest
                            : EllaColors.neutralSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Selected description
        Text(
          _descriptionFor(selected),
          style: GoogleFonts.baloo2(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: EllaColors.neutralSecondary,
          ),
        ),
      ],
    );
  }
}
