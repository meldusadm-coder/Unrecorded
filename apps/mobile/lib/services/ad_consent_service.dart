import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// GDPR/UK consent via Google UMP. Defaults to non-personalised until consented.
class AdConsentService {
  const AdConsentService();

  ConsentRequestParameters get _requestParameters => ConsentRequestParameters(
        consentDebugSettings: kDebugMode
            ? ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
              )
            : null,
      );

  /// Refreshes consent metadata from Google (required before privacy-options checks).
  Future<void> updateConsentInfo() async {
    if (kIsWeb) return;

    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      _requestParameters,
      () {
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        debugPrint('Consent info update failed: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
  }

  Future<void> requestConsentIfNeeded() async {
    if (kIsWeb) return;

    try {
      await updateConsentInfo();
      final consentInfo = ConsentInformation.instance;
      if (await consentInfo.isConsentFormAvailable()) {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      }
    } catch (_) {
      // Consent unavailable (e.g. tests) — continue with non-personalised default.
    }
  }

  /// Whether Settings must show the GDPR revocation / privacy-options entry point.
  Future<bool> isPrivacyOptionsEntryPointRequired() async {
    if (kIsWeb) return false;

    try {
      await updateConsentInfo();
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Reopens Google's consent / privacy-options form (revocation link requirement).
  Future<void> showPrivacyOptionsForm() async {
    if (kIsWeb) return;

    final completer = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) {
        debugPrint('Privacy options form error: ${error.message}');
      }
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
  }

  /// Non-personalised ad request extras for banner loads.
  static AdRequest get adRequest => const AdRequest(
        nonPersonalizedAds: true,
      );
}

final adConsentServiceProvider = Provider<AdConsentService>((ref) {
  return const AdConsentService();
});

/// True when UMP requires an in-app privacy-options / revocation entry point.
final adPrivacyOptionsRequiredProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(adConsentServiceProvider);
  return service.isPrivacyOptionsEntryPointRequired();
});
