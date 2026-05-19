import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Status summary with icon, title, subtitle, and optional last-checked line.
class ScanStatusCard extends StatelessWidget {
  const ScanStatusCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.lastCheckedText,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? lastCheckedText;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeConstants.cardRadius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: iconColor ?? scheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (lastCheckedText != null) ...[
              const SizedBox(height: 10),
              Text(
                lastCheckedText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
