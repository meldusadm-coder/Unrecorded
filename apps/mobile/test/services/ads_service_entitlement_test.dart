import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unrecorded_mobile/services/ad_consent_service.dart';
import 'package:unrecorded_mobile/services/ads_service.dart';
import 'package:unrecorded_mobile/services/entitlement_service.dart';

import '../support/fake_in_app_purchase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AdsService.resetPlatformAttemptCountsForTest();
    AdsService.skipPlatformAdCallsForTest = true;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    AdsService.skipPlatformAdCallsForTest = false;
  });

  ProviderContainer buildContainer({Map<String, Object>? prefs}) {
    SharedPreferences.setMockInitialValues(prefs ?? {});
    return ProviderContainer(
      overrides: [
        adConsentServiceProvider.overrideWithValue(_NoOpAdConsentService()),
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
    );
  }

  test('paid prefs skips init and load attempts', () async {
    final container = buildContainer(prefs: {'ads_removed': true});

    await container.read(adsServiceProvider.future);
    await container.read(entitlementServiceProvider.future);

    expect(AdsService.platformInitAttemptCount, 0);
    expect(AdsService.platformLoadBannerAttemptCount, 0);
    container.dispose();
  });

  test('unpaid prefs reaches init and load attempts in Flutter test', () async {
    final container = buildContainer();

    await container.read(adsServiceProvider.future);
    await container.read(entitlementServiceProvider.future);

    expect(AdsService.platformInitAttemptCount, 1);
    expect(AdsService.platformLoadBannerAttemptCount, 1);
    container.dispose();
  });

  test('adsMayShowProvider false when ads_removed in prefs', () async {
    final container = buildContainer(prefs: {'ads_removed': true});

    await container.read(entitlementServiceProvider.future);
    expect(container.read(adsMayShowProvider), isFalse);
    container.dispose();
  });

  test('adsMayShowProvider false before entitlement resolves', () {
    final container = buildContainer();
    expect(container.read(adsMayShowProvider), isFalse);
    container.dispose();
  });

  test('adsMayShowProvider true when unpaid and entitlement resolved',
      () async {
    final container = buildContainer();

    await container.read(entitlementServiceProvider.future);
    expect(container.read(adsMayShowProvider), isTrue);
    container.dispose();
  });
}

class _NoOpAdConsentService extends AdConsentService {
  @override
  Future<void> requestConsentIfNeeded() async {}
}
