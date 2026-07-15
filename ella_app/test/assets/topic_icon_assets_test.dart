import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/screens/child_view/widgets/topic_icon.dart';

void main() {
  testWidgets('all 71 normalized topic SVGs load and render', (tester) async {
    expect(kBundledTopicIcons, hasLength(71));
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();

    for (final icon in kBundledTopicIcons) {
      final asset = 'assets/topic-icons/$icon.svg';
      expect(assets, contains(asset));
      final source = await rootBundle.loadString(asset);
      final viewBox = RegExp(
        r'viewBox="(-?[\d.]+) (-?[\d.]+) ([\d.]+) ([\d.]+)"',
      ).firstMatch(source);
      expect(viewBox, isNotNull, reason: '$icon needs a normalized viewBox');
      expect(double.parse(viewBox!.group(3)!), 48);
      expect(double.parse(viewBox.group(4)!), 48);
      expect(double.parse(viewBox.group(1)!).abs(), lessThan(8));
      expect(double.parse(viewBox.group(2)!).abs(), lessThan(8));
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(
          children: [
            for (final icon in kBundledTopicIcons)
              SizedBox.square(
                dimension: kTopicIconSize,
                child: SvgPicture.asset('assets/topic-icons/$icon.svg'),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsNWidgets(71));
    expect(tester.takeException(), isNull);
    for (final svg in find.byType(SvgPicture).evaluate()) {
      expect(svg.size, const Size.square(kTopicIconSize));
    }
  });
}
