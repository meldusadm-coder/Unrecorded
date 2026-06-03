// Monetisation is isolated from scan logic.
// This service never receives [DetectedSignal], scan results, or device identifiers.
// Ads use non-personalised requests by default (see [AdConsentService]).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_consent_service.dart';
import 'entitlement_service.dart';

/// Test banner unit ID (Google sample).
const _testBannerId = 'ca-app-pub-3940256099942544/6300978111';

bool get _isFlutterTest =>
    const bool.fromEnvironment('FLUTTER_TEST', defaultValue: false);

String get _bannerAdUnitId {
  const fromEnv = String.fromEnvironment('ADMOB_BANNER_ID');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (kDebugMode) return _testBannerId;
  // Release builds must pass ADMOB_BANNER_ID (see docs/release.md).
  return '';
}

/// Bumped when banner load state changes so [bannerAdWidgetProvider] rebuilds.
final bannerAdRevisionProvider = StateProvider<int>((ref) => 0);

class AdsService {
  AdsService({VoidCallback? onBannerStateChanged})
      : _onBannerStateChanged = onBannerStateChanged;

  final VoidCallback? _onBannerStateChanged;

  @visibleForTesting
  static int platformInitAttemptCount = 0;

  @visibleForTesting
  static int platformLoadBannerAttemptCount = 0;

  @visibleForTesting
  static void resetPlatformAttemptCountsForTest() {
    platformInitAttemptCount = 0;
    platformLoadBannerAttemptCount = 0;
  }

  /// When true, [init] and [loadBanner] increment attempt counters but skip platform SDK calls.
  @visibleForTesting
  static bool skipPlatformAdCallsForTest = false;

  static bool get _shouldInvokePlatformAds =>
      !_isFlutterTest && !skipPlatformAdCallsForTest;

  BannerAd? _bannerAd;
  bool _loaded = false;

  BannerAd? get bannerAd => _loaded ? _bannerAd : null;

  void _notifyBannerStateChanged() => _onBannerStateChanged?.call();

  Future<void> init() async {
    platformInitAttemptCount++;
    if (!_shouldInvokePlatformAds) return;
    await MobileAds.instance.initialize();
  }

  Future<void> loadBanner() async {
    platformLoadBannerAttemptCount++;
    if (!_shouldInvokePlatformAds) return;

    await _bannerAd?.dispose();
    _bannerAd = null;
    _loaded = false;

    final unitId = _bannerAdUnitId;
    if (unitId.isEmpty) {
      _notifyBannerStateChanged();
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: AdConsentService.adRequest,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _loaded = true;
          _notifyBannerStateChanged();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _loaded = false;
          _notifyBannerStateChanged();
        },
      ),
    );

    await _bannerAd!.load();
  }

  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _loaded = false;
  }
}

final adsServiceProvider = FutureProvider<AdsService>((ref) async {
  final entitlement = await ref.watch(entitlementServiceProvider.future);
  if (entitlement.adsRemoved) {
    return AdsService();
  }

  final consent = ref.read(adConsentServiceProvider);
  await consent.requestConsentIfNeeded();

  final service = AdsService(
    onBannerStateChanged: () {
      ref.read(bannerAdRevisionProvider.notifier).update((n) => n + 1);
    },
  );
  await service.init();
  await service.loadBanner();
  ref.onDispose(service.dispose);
  return service;
});

/// Banner widget for [BottomAdSlot], or null when ads removed / not loaded.
final bannerAdWidgetProvider = Provider<Widget?>((ref) {
  if (!ref.watch(adsMayShowProvider)) return null;
  ref.watch(bannerAdRevisionProvider);

  final async = ref.watch(adsServiceProvider);
  return async.maybeWhen(
    data: (service) {
      final ad = service.bannerAd;
      if (ad == null) return null;
      return SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    },
    orElse: () => null,
  );
});
