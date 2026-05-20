import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_mobile/services/remove_ads_pricing.dart';

void main() {
  test('productIdForGbp encodes pence', () {
    expect(RemoveAdsPricing.productIdForGbp(2), 'remove_ads_200');
    expect(RemoveAdsPricing.productIdForGbp(2.5), 'remove_ads_250');
  });

  test('isRemoveAdsProductId accepts dynamic and legacy ids', () {
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_200'), isTrue);
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_3'), isTrue);
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_foo'), isFalse);
    expect(RemoveAdsPricing.isRemoveAdsProductId('other'), isFalse);
  });

  test('parseGbp validates range', () {
    expect(RemoveAdsPricing.parseGbp('2'), 2.0);
    expect(RemoveAdsPricing.parseGbp('£2.50'), 2.5);
    expect(RemoveAdsPricing.parseGbp('0.49'), isNull);
    expect(RemoveAdsPricing.parseGbp('100.01'), isNull);
    expect(RemoveAdsPricing.parseGbp('abc'), isNull);
  });
}
