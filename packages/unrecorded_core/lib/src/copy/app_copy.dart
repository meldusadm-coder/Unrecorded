/// Centralised user-facing copy for calm, plain-English UX.
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

  // Monetisation
  static const String removeAdsTitle = 'Remove ads';

  static const String removeAdsBody =
      'Unrecorded is free to use. If you find it useful, you can choose '
      'what to pay to remove the small ads and support ongoing development.';

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
      'Slide to pick what you’d like to pay, from £0.25 to £20.00 in 25p steps. '
      'Default is £2.00.';

  /// Shown when the store has no product for the selected tier.
  static String removeAdsAmountUnavailable(String formattedAmount) =>
      '$formattedAmount isn’t available for payment right now. '
      'Try another amount on the slider, or check back after the store is updated.';

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
