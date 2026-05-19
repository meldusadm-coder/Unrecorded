import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Product IDs for pay-what-you-want remove-ads tiers (configure in store consoles).
const removeAdsProductIds = <String>[
  'remove_ads_1',
  'remove_ads_3',
  'remove_ads_5',
  'remove_ads_10',
];

const _prefsKeyAdsRemoved = 'ads_removed';

/// Isolated from scan logic — tracks ad-free entitlement only.
class EntitlementService {
  EntitlementService(this._prefs, {InAppPurchase? iap, this.onChanged})
      : _iap = iap ?? InAppPurchase.instance;

  final SharedPreferences _prefs;
  final InAppPurchase _iap;
  final VoidCallback? onChanged;

  static const _devBypass =
      bool.fromEnvironment('UNRECORDED_ADS_REMOVED', defaultValue: false);

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool get adsRemoved =>
      _devBypass || (_prefs.getBool(_prefsKeyAdsRemoved) ?? false);

  Future<void> init() async {
    if (_devBypass) {
      await _prefs.setBool(_prefsKeyAdsRemoved, true);
      return;
    }

    final available = await _iap.isAvailable();
    if (!available) return;

    _purchaseSub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (_) {},
    );
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
  }

  Future<List<ProductDetails>> loadProducts() async {
    if (!await _iap.isAvailable()) return [];
    final response = await _iap.queryProductDetails(removeAdsProductIds.toSet());
    return response.productDetails;
  }

  Future<bool> purchase(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (removeAdsProductIds.contains(purchase.productID)) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          unawaited(_setAdsRemoved(true));
        }
      }
      if (purchase.pendingCompletePurchase) {
        unawaited(_iap.completePurchase(purchase));
      }
    }
  }

  Future<void> _setAdsRemoved(bool value) async {
    await _prefs.setBool(_prefsKeyAdsRemoved, value);
    onChanged?.call();
  }

  /// Dev/test helper.
  @visibleForTesting
  Future<void> setAdsRemovedForTest(bool value) async {
    await _setAdsRemoved(value);
  }
}

final entitlementRefreshProvider = StateProvider<int>((ref) => 0);

final entitlementServiceProvider = FutureProvider<EntitlementService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final service = EntitlementService(
    prefs,
    onChanged: () {
      ref.read(entitlementRefreshProvider.notifier).state++;
    },
  );
  await service.init();
  ref.onDispose(() => service.dispose());
  return service;
});

final adsRemovedProvider = Provider<bool>((ref) {
  ref.watch(entitlementRefreshProvider);
  final devBypass =
      const bool.fromEnvironment('UNRECORDED_ADS_REMOVED', defaultValue: false);
  if (devBypass) return true;

  final async = ref.watch(entitlementServiceProvider);
  return async.maybeWhen(
    data: (s) => s.adsRemoved,
    orElse: () => false,
  );
});
