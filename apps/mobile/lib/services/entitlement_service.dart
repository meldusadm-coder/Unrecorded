import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remove_ads_pricing.dart';

const _prefsKeyAdsRemoved = 'ads_removed';

/// Whether a store purchase should grant remove-ads entitlement.
bool purchaseGrantsRemoveAds(PurchaseDetails purchase) {
  if (!RemoveAdsPricing.isRemoveAdsProductId(purchase.productID)) return false;
  return purchase.status == PurchaseStatus.purchased ||
      purchase.status == PurchaseStatus.restored;
}

/// Isolated from scan logic — tracks ad-free entitlement only.
class EntitlementService {
  EntitlementService(this._prefs, {InAppPurchase? iap, this.onChanged})
      : _iapOverride = iap;

  final SharedPreferences _prefs;
  final InAppPurchase? _iapOverride;
  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;
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

  /// Loads the store product for a user-chosen GBP amount.
  Future<ProductDetails?> loadProductForAmount(double gbp) async {
    if (!await _iap.isAvailable()) return null;
    final id = RemoveAdsPricing.productIdForGbp(gbp);
    final response = await _iap.queryProductDetails({id});
    if (response.productDetails.isEmpty) return null;
    return response.productDetails.first;
  }

  Future<bool> purchase(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    unawaited(_handlePurchaseUpdate(purchases));
  }

  @visibleForTesting
  Future<void> deliverPurchaseUpdates(List<PurchaseDetails> purchases) {
    return _handlePurchaseUpdate(purchases, completePurchases: false);
  }

  Future<void> _handlePurchaseUpdate(
    List<PurchaseDetails> purchases, {
    bool completePurchases = true,
  }) async {
    for (final purchase in purchases) {
      if (purchaseGrantsRemoveAds(purchase)) {
        await _setAdsRemoved(true);
      }
      if (completePurchases && purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _setAdsRemoved(bool value) async {
    if (adsRemoved == value) return;
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

final entitlementServiceProvider =
    FutureProvider<EntitlementService>((ref) async {
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

/// Ads may render only after entitlement is known and user has not paid.
final adsMayShowProvider = Provider<bool>((ref) {
  ref.watch(entitlementRefreshProvider);
  if (const bool.fromEnvironment(
    'UNRECORDED_ADS_REMOVED',
    defaultValue: false,
  )) {
    return false;
  }
  final async = ref.watch(entitlementServiceProvider);
  return async.maybeWhen(
    data: (s) => !s.adsRemoved,
    orElse: () => false,
  );
});
