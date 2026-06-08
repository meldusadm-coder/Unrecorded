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

  static const String protectionStatusNotificationTitle =
      'Unrecorded protection is active';

  static const String protectionStatusNotificationDefaultBody =
      'Watching for possible nearby recording-risk signals.';

  static const String protectionStatusNotificationScanningBody =
      'Scanning is most reliable while the app remains open.';

  static const String notificationModeRiskAlertsOn =
      'Risk alerts on: you\'ll see notifications for possible risk.';

  static const String notificationModeProtectionStatusOn =
      'Protection status on: Android shows Unrecorded while protection is active.';

  static const String notificationModeNotificationsOff =
      'Notifications off: alerts only appear in the app.';

  static const String notificationModeScanningReliability =
      'Scanning is most reliable while the app remains open.';

  static const String notificationPermissionDeniedHelper =
      'Notification permission is off. Enable notifications in system settings '
      'to see protection status and possible-risk alerts outside the app.';

  static const String notificationsHelpTitle = 'What notifications mean';

  static const String notificationsHelpBody =
      'The protection status notification means protection is active while '
      'the app is running — it is not proof that someone is recording. '
      'A possible-risk notification means nearby Bluetooth signals matched '
      'risk indicators, which is also not proof of recording. Scanning '
      'reliability depends on Android, permissions, Bluetooth, and whether '
      'the app can keep running.';

  // Background protection (Android foreground service, opt-in)
  static const String backgroundProtectionTitle = 'Background protection';

  static const String backgroundProtectionSubtitle =
      'Keep scanning while protection is active. Runs with a persistent '
      'notification. Android or battery settings may stop background '
      'protection. Not proof of recording.';

  static const String backgroundProtectionNotificationTitle =
      'Unrecorded protection is active';

  static const String backgroundProtectionNotificationDefaultBody =
      'Watching for possible nearby recording-risk signals.';

  static const String backgroundProtectionStopAction = 'Stop';

  static const String backgroundProtectionNotificationRequired =
      'Notification permission is required for background protection so you '
      'can see and control the persistent notification. Enable notifications '
      'in system settings to turn this on.';

  static const String backgroundProtectionStoppedByAndroid =
      'Background protection was stopped by Android or battery settings. '
      'Tap to restart if you still want protection.';

  static const String backgroundProtectionRestart =
      'Restart background protection';

  static const String backgroundProtectionServiceStartFailed =
      'Could not start background protection. Check Bluetooth and '
      'notification permissions, then try again.';

  static const String backgroundProtectionOnHelper =
      'Background protection on: scanning continues with a persistent '
      'notification while the app is minimised or locked, where Android allows.';

  // Widget lines
  static const String widgetScanningActive = 'Scanning active';
  static const String widgetNoObviousRisk = 'No obvious risk';
  static const String widgetPossibleRisk = 'Possible risk nearby';
  static const String widgetPermissionsNeeded = 'Permissions needed';
  static const String widgetScanningPaused = 'Scanning paused';
  static const String widgetCheckingShortly = 'Checking again shortly';

  // Widget help
  static const String widgetHelpTitle = 'Use the Unrecorded widget';

  static const String widgetHelpBody =
      'Add the Unrecorded widget to your home screen for a quick view of '
      'your current scan status, last checked time, and nearby privacy risk '
      'level. The widget is optional — it helps you keep an eye on possible '
      'nearby smart-glasses signals without opening the app every time. '
      'Add it from your home screen like any other widget.';

  static const String widgetHelpLimitations =
      'Widget updates can depend on your phone\'s battery settings and '
      'operating system limits. Scan data stays on your device. A higher '
      'risk level means nearby signals may match known privacy risk '
      'indicators — it is not proof that anyone is recording.';
}
