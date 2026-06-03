import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/services/entitlement_service.dart';

import '../support/fake_in_app_purchase.dart';

PurchaseDetails _purchase({
  required String productID,
  PurchaseStatus status = PurchaseStatus.purchased,
}) {
  return PurchaseDetails(
    productID: productID,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: 'google_play',
    ),
    transactionDate: null,
    status: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('valid purchase sets ads_removed and calls onChanged once', () async {
    final prefs = await SharedPreferences.getInstance();
    var onChangedCount = 0;
    final service = EntitlementService(
      prefs,
      iap: FakeInAppPurchase(),
      onChanged: () => onChangedCount++,
    );

    await service.deliverPurchaseUpdates([
      _purchase(productID: 'remove_ads_200'),
    ]);

    expect(prefs.getBool('ads_removed'), isTrue);
    expect(service.adsRemoved, isTrue);
    expect(onChangedCount, 1);
  });

  test('duplicate valid purchase is idempotent', () async {
    final prefs = await SharedPreferences.getInstance();
    var onChangedCount = 0;
    final service = EntitlementService(
      prefs,
      iap: FakeInAppPurchase(),
      onChanged: () => onChangedCount++,
    );

    await service.deliverPurchaseUpdates([
      _purchase(productID: 'remove_ads_200'),
    ]);
    await service.deliverPurchaseUpdates([
      _purchase(productID: 'remove_ads_200'),
    ]);

    expect(prefs.getBool('ads_removed'), isTrue);
    expect(onChangedCount, 1);
  });

  test('invalid product does not grant', () async {
    final prefs = await SharedPreferences.getInstance();
    var onChangedCount = 0;
    final service = EntitlementService(
      prefs,
      iap: FakeInAppPurchase(),
      onChanged: () => onChangedCount++,
    );

    await service.deliverPurchaseUpdates([
      _purchase(productID: 'other_product'),
    ]);

    expect(prefs.getBool('ads_removed'), isNull);
    expect(service.adsRemoved, isFalse);
    expect(onChangedCount, 0);
  });

  test('pending purchase does not grant', () async {
    final prefs = await SharedPreferences.getInstance();
    var onChangedCount = 0;
    final service = EntitlementService(
      prefs,
      iap: FakeInAppPurchase(),
      onChanged: () => onChangedCount++,
    );

    await service.deliverPurchaseUpdates([
      _purchase(
        productID: 'remove_ads_200',
        status: PurchaseStatus.pending,
      ),
    ]);

    expect(prefs.getBool('ads_removed'), isNull);
    expect(onChangedCount, 0);
  });

  test('legacy remove_ads_3 restored grants', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = EntitlementService(prefs, iap: FakeInAppPurchase());

    await service.deliverPurchaseUpdates([
      _purchase(
        productID: 'remove_ads_3',
        status: PurchaseStatus.restored,
      ),
    ]);

    expect(service.adsRemoved, isTrue);
  });
}
