import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_mobile/services/remove_ads_pricing.dart';

void main() {
  test('tierCount is 80 from 25p to 20 pounds', () {
    expect(RemoveAdsPricing.tierCount, 80);
    expect(RemoveAdsPricing.amountForTier(0), 0.25);
    expect(RemoveAdsPricing.amountForTier(79), 20.0);
  });

  test('tierIndexForAmount defaults near 2 pounds', () {
    expect(RemoveAdsPricing.tierIndexForAmount(2.0), 7);
    expect(
      RemoveAdsPricing.amountForTier(RemoveAdsPricing.tierIndexForAmount(2.0)),
      2.0,
    );
  });

  test('productIdForGbp encodes pence', () {
    expect(RemoveAdsPricing.productIdForGbp(2), 'remove_ads_200');
    expect(RemoveAdsPricing.productIdForGbp(0.25), 'remove_ads_25');
    expect(RemoveAdsPricing.productIdForGbp(20), 'remove_ads_2000');
  });

  test('isRemoveAdsProductId accepts tier, legacy, and historical ids', () {
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_200'), isTrue);
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_25'), isTrue);
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_3'), isTrue);
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_50'), isTrue);
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_30'), isTrue);
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_2100'), isTrue);
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_foo'), isFalse);
    expect(RemoveAdsPricing.isRemoveAdsProductId('remove_ads_0'), isFalse);
    expect(RemoveAdsPricing.isRemoveAdsProductId('other'), isFalse);
  });

  test('isSupportedAmount only allows 25p grid', () {
    expect(RemoveAdsPricing.isSupportedAmount(2.0), isTrue);
    expect(RemoveAdsPricing.isSupportedAmount(2.5), isTrue);
    expect(RemoveAdsPricing.isSupportedAmount(0.24), isFalse);
    expect(RemoveAdsPricing.isSupportedAmount(20.01), isFalse);
    expect(RemoveAdsPricing.isSupportedAmount(1.3), isFalse);
  });

  test('parseGbp validates tier grid', () {
    expect(RemoveAdsPricing.parseGbp('2'), 2.0);
    expect(RemoveAdsPricing.parseGbp('£2.50'), 2.5);
    expect(RemoveAdsPricing.parseGbp('0.49'), isNull);
    expect(RemoveAdsPricing.parseGbp('100.01'), isNull);
    expect(RemoveAdsPricing.parseGbp('abc'), isNull);
  });
}
