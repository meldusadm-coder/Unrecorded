/// Asset paths for the Unrecorded brand kit (SVG in [package]).
abstract final class UnrecordedAssetPaths {
  /// Package name for [SvgPicture.asset] / [Image.asset].
  static const String package = 'unrecorded_ui';

  static String icon(String name) => 'assets/icons/$name.svg';
  static String status(String name) => 'assets/status/$name.svg';
  static String brand(String name) => 'assets/brand/$name.svg';
  static String navigation(String name) => 'assets/navigation/$name.svg';

  /// Full bundle key (for [rootBundle.load] in tests).
  static String bundleKey(String relativePath) =>
      'packages/$package/$relativePath';

  // Brand
  static const String logoMark = 'assets/brand/unrecorded-logo-mark.svg';
  static const String logoMarkMono =
      'assets/brand/unrecorded-logo-mark-monochrome.svg';
  static const String logoHorizontal =
      'assets/brand/unrecorded-logo-horizontal.svg';

  // Icons
  static const String scan = 'assets/icons/scan.svg';
  static const String protection = 'assets/icons/protection.svg';
  static const String alert = 'assets/icons/alert.svg';
  static const String riskHigh = 'assets/icons/risk-high.svg';
  static const String riskMedium = 'assets/icons/risk-medium.svg';
  static const String riskLow = 'assets/icons/risk-low.svg';
  static const String device = 'assets/icons/device.svg';
  static const String glasses = 'assets/icons/glasses.svg';
  static const String camera = 'assets/icons/camera.svg';
  static const String signal = 'assets/icons/signal.svg';
  static const String info = 'assets/icons/info.svg';
  static const String settings = 'assets/icons/settings.svg';
  static const String help = 'assets/icons/help.svg';
  static const String privacy = 'assets/icons/privacy.svg';
  static const String history = 'assets/icons/history.svg';
  static const String widget = 'assets/icons/widget.svg';
  static const String share = 'assets/icons/share.svg';
  static const String more = 'assets/icons/more.svg';

  // Status badges
  static const String statusProtectionOn = 'assets/status/protection-on.svg';
  static const String statusScanningActive =
      'assets/status/scanning-active.svg';
  static const String statusScanningPaused =
      'assets/status/scanning-paused.svg';
  static const String statusHighRisk = 'assets/status/high-risk.svg';
  static const String statusBluetoothOff = 'assets/status/bluetooth-off.svg';
  static const String statusPermissionsNeeded =
      'assets/status/permissions-needed.svg';

  // Navigation (reserved for future bottom nav)
  static const String navHome = 'assets/navigation/nav-home.svg';
  static const String navAlerts = 'assets/navigation/nav-alerts.svg';
  static const String navDevices = 'assets/navigation/nav-devices.svg';
  static const String navHistory = 'assets/navigation/nav-history.svg';
  static const String navHelp = 'assets/navigation/nav-help.svg';
  static const String navSettings = 'assets/navigation/nav-settings.svg';
}
