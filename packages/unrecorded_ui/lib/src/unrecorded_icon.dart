import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_logo.dart';
import 'unrecorded_assets.dart';

/// Line-style icons from the Unrecorded brand kit.
enum UnrecordedIconAsset {
  scan(UnrecordedAssetPaths.scan),
  protection(UnrecordedAssetPaths.protection),
  alert(UnrecordedAssetPaths.alert),
  riskHigh(UnrecordedAssetPaths.riskHigh),
  riskMedium(UnrecordedAssetPaths.riskMedium),
  riskLow(UnrecordedAssetPaths.riskLow),
  device(UnrecordedAssetPaths.device),
  glasses(UnrecordedAssetPaths.glasses),
  camera(UnrecordedAssetPaths.camera),
  signal(UnrecordedAssetPaths.signal),
  info(UnrecordedAssetPaths.info),
  settings(UnrecordedAssetPaths.settings),
  help(UnrecordedAssetPaths.help),
  privacy(UnrecordedAssetPaths.privacy),
  history(UnrecordedAssetPaths.history),
  widgetIcon(UnrecordedAssetPaths.widget),
  share(UnrecordedAssetPaths.share),
  more(UnrecordedAssetPaths.more);

  const UnrecordedIconAsset(this.assetPath);
  final String assetPath;
}

/// Pre-rendered circular status badges (colours baked into SVG).
enum UnrecordedStatusAsset {
  protectionOn(UnrecordedAssetPaths.statusProtectionOn),
  scanningActive(UnrecordedAssetPaths.statusScanningActive),
  scanningPaused(UnrecordedAssetPaths.statusScanningPaused),
  highRisk(UnrecordedAssetPaths.statusHighRisk),
  bluetoothOff(UnrecordedAssetPaths.statusBluetoothOff),
  permissionsNeeded(UnrecordedAssetPaths.statusPermissionsNeeded);

  const UnrecordedStatusAsset(this.assetPath);
  final String assetPath;
}

Widget _svgFallback({required double size}) => AppLogo(size: size);

Widget _buildSvg({
  required String assetPath,
  required double size,
  ColorFilter? colorFilter,
}) {
  return SvgPicture.asset(
    assetPath,
    package: UnrecordedAssetPaths.package,
    width: size,
    height: size,
    fit: BoxFit.contain,
    colorFilter: colorFilter,
    errorBuilder: (context, error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Unrecorded SVG failed: $assetPath — $error');
      }
      return _svgFallback(size: size);
    },
  );
}

/// Disclosure chevron for list tiles (uses brand more icon).
class UnrecordedListTrailing extends StatelessWidget {
  const UnrecordedListTrailing({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return UnrecordedIcon(
      asset: UnrecordedIconAsset.more,
      size: size,
      color: color ?? scheme.onSurfaceVariant,
    );
  }
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

    return _buildSvg(
      assetPath: asset.assetPath,
      size: size,
      colorFilter: effectiveColor != null
          ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
          : null,
    );
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
    return _buildSvg(
      assetPath: asset.assetPath,
      size: size,
    );
  }
}
