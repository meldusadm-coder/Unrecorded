import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Fixed-height bottom area for banner ads — prevents layout jump.
class BottomAdSlot extends StatelessWidget {
  const BottomAdSlot({
    super.key,
    this.child,
    this.onRemoveAdsTap,
    this.showRemoveAdsLink = true,
  });

  /// Banner ad widget or empty placeholder.
  final Widget? child;

  final VoidCallback? onRemoveAdsTap;
  final bool showRemoveAdsLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showRemoveAdsLink && onRemoveAdsTap != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRemoveAdsTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Remove ads',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        SizedBox(
          height: AppThemeConstants.bottomAdHeight,
          width: double.infinity,
          child: child ??
              Center(
                child: Text(
                  '',
                  style: theme.textTheme.bodySmall,
                ),
              ),
        ),
      ],
    );
  }
}
