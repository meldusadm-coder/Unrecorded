/// Centralised user-facing copy for calm, plain-English UX.
///
/// Monetisation copy (remove-ads / IAP) lives in
/// `apps/mobile/lib/copy/monetisation_copy.dart` — it is app-specific and
/// does not belong in the pure-Dart core library.
class AppCopy {
  AppCopy._();

  // Scan screen
  static const String scanHelper =
      'Unrecorded looks for nearby device signals that could indicate '
      'recording-enabled smart glasses or similar devices. It cannot '
      'guarantee that recording is happening.';

  static const String scanningActive =
      'Scanning nearby signals for possible recording risk.';

  static const String scanResting =
      'Checking again shortly. Keep the app open for the most reliable scanning.';

  static const String confirmingRisk =
      'Confirming a possible risk signal nearby.';

  static const String demoModeBanner =
      'Demo mode — using sample scan data, not live Bluetooth.';

  static const String notProofOfRecording =
      'This is not proof that someone is recording.';

  static const String noRiskWhileScanning =
      'No obvious recording risk detected right now. '
      'Keep scanning active for ongoing checks.';

  static const String possibleRiskTitle = 'Possible recording risk nearby';

  static const String possibleRiskBody =
      'We found a signal pattern that may need your attention.';

  static const String alertCardTitle = 'Possible recording risk nearby';

  static const String alertCardBody =
      'A nearby signal looks similar to a device that may support recording. '
      'This does not confirm recording is happening.';

  static const String alertExampleFooter =
      'Alerts are designed to be cautious, not certain. Use them as a prompt '
      'to be more aware of your surroundings.';

  static const String riskResultHelper =
      'This is a signal-based warning. It means something nearby may match '
      'a known pattern, not that recording is confirmed.';

  // Permissions
  static const String permissionHelper =
      'Nearby scanning needs Bluetooth access to check for nearby signals '
      'that may match recording-device patterns. Scan data stays on your '
      'device and is not used to track where you go.';
  static const String permissionPermanentlyDeniedHelper =
      'Bluetooth permission is blocked. Open system settings to allow Nearby '
      'Devices access for scanning.';

  static const String permissionRequiredTitle = 'Permissions needed';

  static const String bluetoothOffMessage =
      'Bluetooth appears to be off. Turn it on and try again.';

  static const String bluetoothUnsupportedMessage =
      'Bluetooth scanning is not supported on this device. '
      'You can use demo mode for a preview.';
  static const String scanErrorMessage =
      'Scanning is temporarily unavailable. Please try again in a moment.';

  // Actions
  static const String turnOnProtection = 'Turn on protection';
  static const String pauseProtection = 'Pause protection';

  // Notifications
  static const String riskNotificationsTitle = 'Risk alerts';
  static const String riskNotificationsSubtitle =
      'Show a notification when possible recording risk is detected while '
      'protection is active. Background behaviour may be limited by Android; '
      'keep the app open for the most reliable scanning.';

  static const String riskNotificationLevelTitle = 'Notify me for';
  static const String riskNotificationLevelSubtitle =
      'Choose the minimum risk level before a notification is sent. '
      'The in-app alert on the scan screen is unchanged.';

  // Widget lines
  static const String widgetScanningActive = 'Scanning active';
  static const String widgetNoObviousRisk = 'No obvious risk';
  static const String widgetPossibleRisk = 'Possible risk nearby';
  static const String widgetPermissionsNeeded = 'Permissions needed';
  static const String widgetScanningPaused = 'Scanning paused';
  static const String widgetCheckingShortly = 'Checking again shortly';
}
