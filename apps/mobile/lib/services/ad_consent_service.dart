import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// GDPR/UK consent via Google UMP. Defaults to non-personalised until consented.
class AdConsentService {
  const AdConsentService();

  Future<void> requestConsentIfNeeded() async {
    if (kIsWeb) return;

    try {
      final params = ConsentRequestParameters(
        consentDebugSettings: kDebugMode
            ? ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
              )
            : null,
      );

      final consentInfo = ConsentInformation.instance;
      consentInfo.requestConsentInfoUpdate(
        params,
        () async {
          try {
            if (await consentInfo.isConsentFormAvailable()) {
              await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
            }
          } catch (_) {}
        },
        (FormError error) {
          debugPrint('Consent info update failed: ${error.message}');
        },
      );
    } catch (_) {
      // Consent unavailable (e.g. tests) — continue with non-personalised default.
    }
  }

  /// Non-personalised ad request extras for banner loads.
  static AdRequest get adRequest => const AdRequest(
        nonPersonalizedAds: true,
      );
}

final adConsentServiceProvider = Provider<AdConsentService>((ref) {
  return const AdConsentService();
});
