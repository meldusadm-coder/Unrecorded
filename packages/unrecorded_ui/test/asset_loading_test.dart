import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('brand assets', () {
    test('bundle contains scan svg via package key', () async {
      await rootBundle.load(UnrecordedAssetPaths.bundleKey(UnrecordedAssetPaths.scan));
    });

    test('bundle contains status badge svg', () async {
      await rootBundle.load(
        UnrecordedAssetPaths.bundleKey(UnrecordedAssetPaths.statusHighRisk),
      );
    });

    test('SvgAssetLoader resolves package-relative path', () async {
      final loader = SvgAssetLoader(
        UnrecordedAssetPaths.icon('scan'),
        packageName: UnrecordedAssetPaths.package,
      );
      final data = await loader.prepareMessage(null);
      expect(data, isNotNull);
      expect(data!.lengthInBytes, greaterThan(0));
    });

    testWidgets('UnrecordedStatusIcon has non-zero size after paint',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnrecordedStatusIcon(
              asset: UnrecordedStatusAsset.highRisk,
              size: 48,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final box = tester.renderObject<RenderBox>(
        find.byType(UnrecordedStatusIcon),
      );
      expect(box.size.width, 48);
      expect(box.size.height, 48);
    });
  });
}
