import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/core/curriculum_icons.dart';

void main() {
  group('CurriculumIcons', () {
    test('maps representative and boundary skills for every transition', () {
      final cases = [
        ('A0', 1, 'U1-VOC-01', 'a0-a1/01-rainbow.svg'),
        ('A0', 5, 'U5-FLU-02', 'a0-a1/20-sparkle.svg'),
        ('A1', 1, 'U1-VOC-01', 'a1-a2/01-two-faces.svg'),
        ('A1', 5, 'U5-FLU-02', 'a1-a2/19-strong-arm.svg'),
        ('A2', 1, 'U1-VOC-01', 'a2-b1/01-palette.svg'),
        ('A2', 5, 'U5-FLU-02', 'a2-b1/20-join-in.svg'),
        ('B1', 1, 'U1-VOC-01', 'b1-b2/01-gem.svg'),
        ('B1', 5, 'U5-FLU-02', 'b1-b2/20-heart-key.svg'),
        ('B2', 1, 'U1-VOC-01', 'b2-c1/01-grad-cap.svg'),
        ('B2', 5, 'U5-FLU-02', 'b2-c1/19-sailboat.svg'),
        ('C1', 1, 'U1-VOC-01', 'c1-c2/01-pen-nib.svg'),
        ('C1', 5, 'U5-FLU-02', 'c1-c2/19-golden-bridge.svg'),
      ];

      for (final item in cases) {
        expect(
          CurriculumIcons.skillAsset(item.$1, item.$2, item.$3),
          'assets/skill-icons/${item.$4}',
        );
      }
    });

    test('maps colored and stone unit assets', () {
      expect(
        CurriculumIcons.unitAsset('A1', 4),
        'assets/unit-icons/a1-a2/u4-signpost.svg',
      );
      expect(
        CurriculumIcons.unitAsset('A1', 4, variant: UnitIconVariant.stone),
        'assets/unit-icons/a1-a2/u4-signpost-stone.svg',
      );
      expect(
        CurriculumIcons.unitAsset('C1', 5, variant: UnitIconVariant.stone),
        'assets/unit-icons/c1-c2/u5-crown-stone.svg',
      );
    });

    test('rejects unknown levels, mismatched units, and unknown skills', () {
      expect(CurriculumIcons.unitAsset('C2', 1), isNull);
      expect(CurriculumIcons.skillAsset('A1', 2, 'U1-VOC-01'), isNull);
      expect(CurriculumIcons.skillAsset('A1', 1, 'U1-GRA-02'), isNull);
      expect(CurriculumIcons.skillAsset('A1', 1, 'unknown-skill'), isNull);
    });
  });
}
