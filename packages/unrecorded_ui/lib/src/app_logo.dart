import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'unrecorded_assets.dart';

/// Brand shield mark from the Unrecorded design kit.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 28,
    this.forColoredBackground = false,
  });

  final double size;

  /// Light mark for primary/danger buttons (same logo as the app bar, inverted).
  final bool forColoredBackground;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assetPath = forColoredBackground || isDark
        ? UnrecordedAssetPaths.logoMarkMono
        : UnrecordedAssetPaths.logoMark;

    final colorFilter = forColoredBackground
        ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
        : (isDark
            ? ColorFilter.mode(
                Theme.of(context).colorScheme.onSurface,
                BlendMode.srcIn,
              )
            : null);

    return SvgPicture.asset(
      assetPath,
      package: UnrecordedAssetPaths.package,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: colorFilter,
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('AppLogo SVG failed: $assetPath — $error');
        }
        return SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}
