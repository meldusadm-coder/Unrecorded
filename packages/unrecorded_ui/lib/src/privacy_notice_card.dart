import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'unrecorded_icon.dart';

/// A calm, informational card for displaying privacy-related notices.
class PrivacyNoticeCard extends StatelessWidget {
  final String text;
  final Widget? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PrivacyNoticeCard({
    super.key,
    required this.text,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leading = icon ??
        UnrecordedIcon(
          asset: UnrecordedIconAsset.info,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        );
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeConstants.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (actionLabel != null && onAction != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onAction,
                      child: Text('$actionLabel ›'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
