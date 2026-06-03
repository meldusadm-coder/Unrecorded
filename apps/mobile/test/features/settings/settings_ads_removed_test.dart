import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/app.dart';
import 'package:unrecorded_mobile/app_bootstrap.dart';
import 'package:unrecorded_mobile/copy/monetisation_copy.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';
import 'package:unrecorded_mobile/services/entitlement_service.dart';

import '../../support/fake_in_app_purchase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'ads_removed': true});
  });

  Widget testApp() => ProviderScope(
        overrides: [
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
        ],
        child: const AppBootstrap(child: UnrecordedApp()),
      );

  testWidgets('settings keeps Remove ads row with paid subtitle',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text(MonetisationCopy.removeAdsTitle), findsOneWidget);
    expect(
      find.text('Ads are removed on this device. Thank you for your support.'),
      findsOneWidget,
    );
  });

  testWidgets('settings Remove ads opens entitled screen without slider',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp());
    await tester.pump();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text(MonetisationCopy.removeAdsTitle));
    await tester.pumpAndSettle();

    expect(find.text('Ads are removed on this device.'), findsOneWidget);
    expect(find.byKey(const Key('remove_ads_amount_slider')), findsNothing);
    expect(find.text(MonetisationCopy.removeAdsAmountLabel), findsNothing);
  });
}
