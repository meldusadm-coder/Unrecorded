import 'package:flutter/material.dart';

/// Line-style icons from the Unrecorded brand kit.
enum UnrecordedIconAsset {
  scan('scan'),
  protection('protection'),
  alert('alert'),
  riskHigh('risk_high'),
  riskMedium('risk_medium'),
  riskLow('risk_low'),
  device('device'),
  glasses('glasses'),
  camera('camera'),
  signal('signal'),
  info('info'),
  settings('settings'),
  help('help'),
  privacy('privacy'),
  history('history'),
  widget('widget'),
  share('share'),
  more('more');

  const UnrecordedIconAsset(this.fileName);
  final String fileName;

  String get assetPath => 'packages/unrecorded_ui/assets/icons/$fileName.png';
}

/// Pre-rendered circular status badges (backgrounds baked in).
enum UnrecordedStatusAsset {
  protectionOn('protection_on'),
  scanningActive('scanning_active'),
  scanningPaused('scanning_paused'),
  highRisk('high_risk'),
  bluetoothOff('bluetooth_off'),
  permissionsNeeded('permissions_needed');

  const UnrecordedStatusAsset(this.fileName);
  final String fileName;

  String get assetPath => 'packages/unrecorded_ui/assets/status/$fileName.png';
}

/// Brand line icon with optional tint for light/dark themes.
class UnrecordedIcon extends StatelessWidget {
  const UnrecordedIcon({
    super.key,
    required this.asset,
    this.size = 24,
    this.color,
  });

  final UnrecordedIconAsset asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : null);

    Widget image = Image.asset(
      asset.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (effectiveColor != null) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
        child: image,
      );
    }

    return image;
  }
}

/// Circular status badge from the brand kit (not tinted).
class UnrecordedStatusIcon extends StatelessWidget {
  const UnrecordedStatusIcon({
    super.key,
    required this.asset,
    this.size = 48,
  });

  final UnrecordedStatusAsset asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
