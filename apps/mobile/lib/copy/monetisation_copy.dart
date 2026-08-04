/// App-only copy for the monetisation (remove-ads) feature.
///
/// Kept in apps/mobile because these strings are specific to IAP/ads
/// and have no reason to live in the pure-Dart core library.
class MonetisationCopy {
  MonetisationCopy._();

  static const String removeAdsTitle = 'Remove ads';

  static const String removeAdsBody =
      'Unrecorded remains free. Payment removes ads and supports development. '
      'Choose an amount from \u00a30.25\u2013\u00a320 (default \u00a32).';

  static const String removeAdsFreeNote =
      'Core scanning stays free. Payment only removes ads.';

  static const String adPrivacyChoicesTitle = 'Ad privacy choices';
  static const String adPrivacyChoicesSubtitle =
      'Change or withdraw consent for advertising cookies and data use.';

  static const String maybeLater = 'Maybe later';
  static const String restorePurchase = 'Restore purchase';
  static const String restorePurchaseHint =
      'Restore requested. If you previously paid, ads will be removed.';

  static const String removeAdsAmountLabel = 'Choose your amount';
  static const String removeAdsAmountHint =
      'Slide to pick what you\u2019d like to pay, from \u00a30.25 to \u00a320.00 in 25p steps. '
      'Default is \u00a32.00.';

  /// Shown when the store has no product for the selected tier.
  static String removeAdsAmountUnavailable(String formattedAmount) =>
      '$formattedAmount isn\u2019t available for payment right now. '
      'Try another amount on the slider, or check back after the store is updated.';
}
