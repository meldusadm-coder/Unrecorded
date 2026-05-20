import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'unrecorded_assets.dart';

/// Brand shield mark from the Unrecorded design kit.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assetPath =
        isDark ? UnrecordedAssetPaths.logoMarkMono : UnrecordedAssetPaths.logoMark;

    return SvgPicture.asset(
      assetPath,
      package: UnrecordedAssetPaths.package,
      width: size,
      height: size,
      fit: BoxFit.contain,
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
