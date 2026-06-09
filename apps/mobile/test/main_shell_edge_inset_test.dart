import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/features/scan/scan_state.dart';
import 'package:unrecorded_mobile/main_shell.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';
import 'package:unrecorded_mobile/services/entitlement_service.dart';
import 'package:unrecorded_mobile/services/scanner_provider.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import 'support/fake_in_app_purchase.dart';
import 'support/scan_test_harness.dart';

const _bottomInset = 48.0;
const _mockAdHeight = 56.0;
const _removeAdsRowHeight = 44.0;
const _gapBelowLink = 8.0;
const _expectedAdSlotHeight =
    _removeAdsRowHeight + _gapBelowLink + _mockAdHeight;

Widget _harness({
  required String location,
  required bool showAds,
  bool showBanner = true,
  ScanState? scanState,
  double bottomInset = _bottomInset,
}) {
  return ProviderScope(
    overrides: [
      adsMayShowProvider.overrideWith((ref) => showAds),
      adsServiceProvider.overrideWith((ref) async => AdsService()),
      entitlementServiceProvider.overrideWith((ref) async {
        final prefs = await SharedPreferences.getInstance();
        final service = EntitlementService(
          prefs,
          iap: FakeInAppPurchase(),
          onChanged: () {
            ref.read(entitlementRefreshProvider.notifier).state++;
          },
        );
        await service.init();
        return service;
      }),
      if (scanState != null)
        scanControllerProvider.overrideWith(
          (ref) => StateHarnessController(scanState),
        ),
      bannerAdWidgetProvider.overrideWith((ref) {
        if (!showBanner) return null;
        return const SizedBox(
          key: Key('mock_banner'),
          height: _mockAdHeight,
          width: double.infinity,
          child: ColoredBox(color: Colors.red),
        );
      }),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        viewPadding: EdgeInsets.only(bottom: bottomInset),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: MainShell(
            location: location,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

Finder get _shellBottomPadding => find.ancestor(
      of: find.byType(BottomAdSlot),
      matching: find.byType(Padding),
    );

double _shellBottomPaddingHeight(WidgetTester tester) {
  return tester.getSize(_shellBottomPadding).height;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ads shown: banner sits above system bottom inset',
      (tester) async {
    await tester.pumpWidget(
      _harness(location: '/help', showAds: true, showBanner: true),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mock_banner')), findsOneWidget);
    expect(
      _shellBottomPaddingHeight(tester),
      closeTo(_bottomInset + _expectedAdSlotHeight, 1.0),
    );

    final bannerBox =
        tester.renderObject<RenderBox>(find.byKey(const Key('mock_banner')));
    final screenBox =
        tester.renderObject<RenderBox>(find.byType(Scaffold).first);
    final bannerBottom =
        bannerBox.localToGlobal(Offset.zero).dy + bannerBox.size.height;
    final gapToScreenBottom = screenBox.size.height - bannerBottom;

    expect(gapToScreenBottom, closeTo(_bottomInset, 1.0));
  });

  testWidgets('ads hidden on scan alert: only system bottom inset reserved',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        location: '/',
        showAds: true,
        showBanner: true,
        scanState: const ScanState(
          status: ScanStatus.possibleRiskDetected,
          protectionRequested: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mock_banner')), findsNothing);
    expect(find.text('Remove ads'), findsNothing);
    expect(_shellBottomPaddingHeight(tester), closeTo(_bottomInset, 1.0));
  });

  testWidgets('ads removed: only system bottom inset reserved', (tester) async {
    SharedPreferences.setMockInitialValues({'ads_removed': true});

    await tester.pumpWidget(
      _harness(location: '/help', showAds: false, showBanner: false),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mock_banner')), findsNothing);
    expect(_shellBottomPaddingHeight(tester), closeTo(_bottomInset, 1.0));
  });

  testWidgets('zero bottom inset when ads hidden adds no extra gap',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsMayShowProvider.overrideWith((ref) => false),
        ],
        child: const MediaQuery(
          data: MediaQueryData(size: Size(400, 800)),
          child: MaterialApp(
            home: Scaffold(
              body: MainShell(
                location: '/help',
                child: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_shellBottomPaddingHeight(tester), closeTo(0, 1.0));
  });
}
