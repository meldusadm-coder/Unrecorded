import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('brand assets', () {
    test('bundle contains every line icon svg', () async {
      for (final asset in UnrecordedIconAsset.values) {
        await rootBundle.load(
          UnrecordedAssetPaths.bundleKey(asset.assetPath),
        );
      }
    });

    test('bundle contains every status badge svg', () async {
      for (final asset in UnrecordedStatusAsset.values) {
        await rootBundle.load(
          UnrecordedAssetPaths.bundleKey(asset.assetPath),
        );
      }
    });

    test('bundle contains logo mark svg', () async {
      await rootBundle.load(
        UnrecordedAssetPaths.bundleKey(UnrecordedAssetPaths.logoMark),
      );
    });

    testWidgets('UnrecordedIcon renders with non-zero size', (tester) async {
      for (final asset in UnrecordedIconAsset.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UnrecordedIcon(asset: asset, size: 24),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final box = tester.renderObject<RenderBox>(
          find.byType(UnrecordedIcon),
        );
        expect(box.size.width, 24);
        expect(box.size.height, 24);
      }
    });

    testWidgets('UnrecordedStatusIcon renders with non-zero size',
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
      await tester.pump();
      expect(tester.takeException(), isNull);

      final box = tester.renderObject<RenderBox>(
        find.byType(UnrecordedStatusIcon),
      );
      expect(box.size.width, 48);
      expect(box.size.height, 48);
    });

    testWidgets('AppLogo renders without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppLogo(size: 28)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
