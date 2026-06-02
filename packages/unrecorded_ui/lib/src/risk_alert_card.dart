import 'package:flutter/material.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import 'app_theme.dart';
import 'risk_badge.dart';
import 'unrecorded_icon.dart';

/// Cautious alert card for possible recording risk (live or example).
///
/// Set [isExample] to `true` in help/onboarding contexts to render a small
/// "Example" label so users understand the card is illustrative, not live.
class RiskAlertCard extends StatelessWidget {
  const RiskAlertCard({
    super.key,
    required this.title,
    required this.body,
    this.level,
    this.onViewDetails,
    this.onDismiss,
    this.isExample = false,
  });

  final String title;
  final String body;
  final RiskLevel? level;
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
            if (isExample) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(AppThemeConstants.cardRadius),
                  ),
                  child: Text(
                    'Example',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UnrecordedIcon(
                  asset: UnrecordedIconAsset.alert,
                  size: 22,
                  color: scheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (level != null) ...[
                        RiskBadge(level: level!),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
