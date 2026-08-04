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

  /// Privacy-model summary for the settings screen (full sheet content).
  static const String privacyModel =
      'All scanning happens on your device. No account is required. '
      'No data is uploaded by default. No analytics or telemetry are included. '
      'Optional banner ads never receive scan results or nearby device data.';

  /// Concise on-screen reassurance for Settings.
  static const String privacyModelConcise = 'Scanning stays on this device';

  /// Funding transparency note (disclosure sheet body).
  static const String fundingNote =
      'Official builds may include small ads to support development. '
      'Scan results and nearby-device data are not sent to ad networks. '
      'You can choose a pay-what-you-like purchase to remove ads. '
      'Core detection does not depend on payment or tracking.';

  /// Short funding trigger line for Settings.
  static const String fundingNoteShort = 'How Unrecorded is funded';
}
