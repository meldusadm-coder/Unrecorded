import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/copy/monetisation_copy.dart';
import 'package:unrecorded_mobile/features/monetisation/remove_ads_screen.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';
import 'package:unrecorded_mobile/services/entitlement_service.dart';
import 'package:unrecorded_mobile/services/remove_ads_pricing.dart';

import '../../support/fake_in_app_purchase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildScreen({Map<String, Object> prefs = const {}}) {
    SharedPreferences.setMockInitialValues(prefs);
    return ProviderScope(
      overrides: [
        adsServiceProvider.overrideWith((ref) async => AdsService()),
        entitlementServiceProvider.overrideWith((ref) async {
          final shared = await SharedPreferences.getInstance();
          final service = EntitlementService(
            shared,
            iap: FakeInAppPurchase(),
          );
          await service.init();
          return service;
        }),
      ],
      child: const MaterialApp(home: RemoveAdsScreen()),
    );
  }

  void expectEntitledUiAbsent() {
    expect(find.text('Ads are removed on this device.'), findsOneWidget);
    expect(find.byKey(const Key('remove_ads_amount_slider')), findsNothing);
    expect(find.text(MonetisationCopy.removeAdsAmountLabel), findsNothing);
    expect(find.textContaining('Pay £'), findsNothing);
    expect(find.text('Ads already removed'), findsNothing);
    expect(find.text(MonetisationCopy.restorePurchase), findsOneWidget);
  }

  testWidgets('shows slider with default £2.00', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('remove_ads_amount_slider')), findsOneWidget);
    expect(find.text('£2.00'), findsWidgets);
    expect(find.text(MonetisationCopy.removeAdsAmountLabel), findsOneWidget);
  });

  testWidgets('slider changes displayed amount', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final slider = find.byKey(const Key('remove_ads_amount_slider'));
    expect(slider, findsOneWidget);

    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.right - 8, rect.center.dy));
    await tester.pump();

    final highAmount = RemoveAdsPricing.formatGbp(
      RemoveAdsPricing.amountForTier(RemoveAdsPricing.tierCount - 1),
    );
    expect(find.text(highAmount), findsWidgets);
  });

  testWidgets('prefs ads_removed shows entitled UI without purchase controls',
      (tester) async {
    await tester.pumpWidget(buildScreen(prefs: {'ads_removed': true}));
    await tester.pumpAndSettle();

    expectEntitledUiAbsent();
  });

  testWidgets('adsRemovedProvider override shows entitled UI without purchase',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsServiceProvider.overrideWith((ref) async => AdsService()),
          adsRemovedProvider.overrideWith((ref) => true),
          entitlementServiceProvider.overrideWith((ref) async {
            final prefs = await SharedPreferences.getInstance();
            final service = EntitlementService(
              prefs,
              iap: FakeInAppPurchase(),
            );
            await service.init();
            return service;
          }),
        ],
        child: const MaterialApp(home: RemoveAdsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expectEntitledUiAbsent();
  });
}
