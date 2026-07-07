import 'package:ella_app/core/theme_colors.dart';
import 'package:ella_app/screens/child_view/widgets/ella_primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EllaPrimaryButton uses smoothed superellipse corners', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 220,
            child: EllaPrimaryButton(label: "Let's Talk", onTap: () {}),
          ),
        ),
      ),
    );

    final buttonContainer = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = buttonContainer.decoration;

    expect(decoration, isA<ShapeDecoration>());
    final shape = (decoration! as ShapeDecoration).shape;
    expect(shape, isA<RoundedSuperellipseBorder>());
    final border = shape as RoundedSuperellipseBorder;
    expect(border.borderRadius, const BorderRadius.all(Radius.circular(999)));
    expect(border.side.color, EllaColors.berryDeep);
    expect(border.side.width, 3);
  });
}
