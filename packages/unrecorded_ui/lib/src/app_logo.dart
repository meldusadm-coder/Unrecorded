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
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
