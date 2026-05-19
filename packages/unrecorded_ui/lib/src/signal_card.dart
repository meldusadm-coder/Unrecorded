import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Displays a single detected signal in a compact card format.
class SignalCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final int? rssi;
  final bool isSuspicious;

  const SignalCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.rssi,
    this.isSuspicious = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final suspiciousBg = isDark
        ? AppThemeConstants.suspiciousBackgroundDark
        : AppThemeConstants.suspiciousBackgroundLight;
    final suspiciousBorder = isDark
        ? AppThemeConstants.suspiciousBorderDark
        : AppThemeConstants.suspiciousBorderLight;

    return Card(
      elevation: 0,
      color: isSuspicious
          ? suspiciousBg
          : theme.colorScheme.surfaceContainerHighest.withAlpha(60),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeConstants.cardRadius),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isSuspicious ? Icons.warning_amber_rounded : Icons.bluetooth,
          color: isSuspicious
              ? suspiciousBorder
              : theme.colorScheme.onSurfaceVariant,
          size: 22,
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: isSuspicious ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: rssi != null
            ? Text(
                '$rssi dBm',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
      ),
    );
  }
}
