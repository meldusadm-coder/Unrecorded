/// Centralised privacy disclaimers used throughout the app.
///
/// Keeping these in one place makes it easy to review and update the
/// language, and prevents inconsistency.
class PrivacyDisclaimer {
  PrivacyDisclaimer._();

  /// Main detection-capability disclaimer.
  static const String detectionDisclaimer =
      'Unrecorded can alert you to possible nearby smart glasses or '
      'wearable recording devices. It cannot prove that a device is recording.';

  /// Short tagline for marketing / about screens.
  static const String tagline =
      'Unrecorded detects possible smart glasses or wearable recording '
      'devices nearby and alerts you to potential recording risk.';

  /// Privacy-model summary for the settings screen.
  static const String privacyModel =
      'All scanning happens on your device. No account is required. '
      'No data is uploaded by default. No analytics or tracking are included.';

  /// Funding transparency note.
  static const String fundingNote =
      'Official builds may later include small, privacy-respecting ads to '
      'support development, with an optional pay-what-you-like way to remove '
      'them. The core detection engine does not depend on ads or tracking.';
}
