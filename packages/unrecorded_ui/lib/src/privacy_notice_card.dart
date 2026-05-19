import 'package:flutter/material.dart';

import 'unrecorded_icon.dart';

/// A calm, informational card for displaying privacy-related notices.
class PrivacyNoticeCard extends StatelessWidget {
  final String text;
  final Widget? icon;

  const PrivacyNoticeCard({
    super.key,
    required this.text,
    this.icon,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
