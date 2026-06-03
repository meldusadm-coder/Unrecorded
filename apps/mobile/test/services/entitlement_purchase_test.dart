import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:unrecorded_mobile/services/entitlement_service.dart';

PurchaseDetails _purchase({
  required String productID,
  required PurchaseStatus status,
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
  group('purchaseGrantsRemoveAds', () {
    test('remove_ads_200 purchased and restored grant', () {
      expect(
        purchaseGrantsRemoveAds(
          _purchase(
            productID: 'remove_ads_200',
            status: PurchaseStatus.purchased,
          ),
        ),
        isTrue,
      );
      expect(
        purchaseGrantsRemoveAds(
          _purchase(
            productID: 'remove_ads_200',
            status: PurchaseStatus.restored,
          ),
        ),
        isTrue,
      );
    });

    test('tier and legacy product IDs grant on purchased', () {
      for (final id in [
        'remove_ads_25',
        'remove_ads_2000',
        'remove_ads_3',
        'remove_ads_2100',
      ]) {
        expect(
          purchaseGrantsRemoveAds(
            _purchase(productID: id, status: PurchaseStatus.purchased),
          ),
          isTrue,
          reason: id,
        );
      }
    });

    test('invalid product IDs do not grant', () {
      for (final id in ['remove_ads_0', 'remove_ads_foo', 'other_product']) {
        expect(
          purchaseGrantsRemoveAds(
            _purchase(productID: id, status: PurchaseStatus.purchased),
          ),
          isFalse,
          reason: id,
        );
      }
    });

    test('non-terminal statuses do not grant', () {
      for (final status in [
        PurchaseStatus.pending,
        PurchaseStatus.error,
        PurchaseStatus.canceled,
      ]) {
        expect(
          purchaseGrantsRemoveAds(
            _purchase(productID: 'remove_ads_200', status: status),
          ),
          isFalse,
          reason: status.name,
        );
      }
    });
  });
}
