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
      'Nearby scanning needs Bluetooth and/or location-style permissions '
      'depending on your device. These permissions help detect nearby '
      'signals — they are not used to track where you go.';

  static const String permissionRequiredTitle = 'Permissions needed';

  static const String bluetoothOffMessage =
      'Bluetooth appears to be off. Turn it on and try again.';

  static const String bluetoothUnsupportedMessage =
      'Bluetooth scanning is not supported on this device. '
      'You can use demo mode for a preview.';

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

  static const String removeAdsAmountLabel = 'Your amount (GBP)';
  static const String removeAdsAmountHint =
      'Choose what you’d like to pay. Default is £2.00. Not every amount is '
      'available in the app store — use the check button beside the field '
      'to confirm yours before paying.';
  static const String removeAdsInvalidAmount =
      'Enter an amount between £0.50 and £100.00.';

  /// Shown when the store has no product for the user’s chosen GBP amount.
  static String removeAdsAmountUnavailable(String formattedAmount) =>
      '$formattedAmount isn’t available for payment right now. '
      'Try £2.00, £5.00, or £10.00, or use the check button to try another amount.';

  // Notifications
  static const String riskNotificationsTitle = 'Risk alerts';
  static const String riskNotificationsSubtitle =
      'Show a notification when possible recording risk is detected '
      '(including when the app is in the background).';

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
}
