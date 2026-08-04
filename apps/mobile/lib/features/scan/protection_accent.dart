import 'package:flutter/material.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

/// Semantic accent for protection presentation; widgets resolve to theme colours.
enum ProtectionAccent {
  muted,
  primary,
  warning,
  danger,
  info,
}

extension ProtectionAccentColor on ProtectionAccent {
  Color resolve(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (this) {
      ProtectionAccent.muted => UnrecordedColors.muted,
      ProtectionAccent.primary => scheme.primary,
      ProtectionAccent.warning => UnrecordedColors.warning,
      ProtectionAccent.danger => UnrecordedColors.danger,
      ProtectionAccent.info => UnrecordedColors.info,
    };
  }
}
