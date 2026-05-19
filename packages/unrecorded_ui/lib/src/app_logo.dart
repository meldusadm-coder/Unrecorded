import 'package:flutter/material.dart';

/// Brand shield mark from the Unrecorded design kit.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 28});

  final double size;

  static const _assetPath = 'packages/unrecorded_ui/assets/brand/logo_mark.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
