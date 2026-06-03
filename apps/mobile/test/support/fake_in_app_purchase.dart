import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Avoids touching platform billing channels in unit/widget tests.
class FakeInAppPurchase extends Fake implements InAppPurchase {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async =>
      ProductDetailsResponse(
        productDetails: [],
        notFoundIDs: identifiers.toList(),
      );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      false;

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}
