import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Cautious alert card for possible recording risk (live or example).
class RiskAlertCard extends StatelessWidget {
  const RiskAlertCard({
    super.key,
    required this.title,
    required this.body,
    this.onViewDetails,
    this.onDismiss,
    this.isExample = false,
  });

  final String title;
  final String body;
  final VoidCallback? onViewDetails;
  final VoidCallback? onDismiss;
  final bool isExample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final borderColor = scheme.error.withValues(alpha: 0.35);
    final bgColor = scheme.errorContainer.withValues(alpha: 0.25);

    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeConstants.cardRadius),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: scheme.error, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (onViewDetails != null || onDismiss != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onDismiss != null)
                    TextButton(
                      onPressed: onDismiss,
                      child: const Text('Dismiss'),
                    ),
                  if (onViewDetails != null)
                    FilledButton.tonal(
                      onPressed: onViewDetails,
                      child: const Text('View details'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
