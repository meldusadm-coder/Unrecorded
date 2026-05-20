import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Fixed-height bottom area for banner ads — prevents layout jump.
class BottomAdSlot extends StatelessWidget {
  const BottomAdSlot({
    super.key,
    this.child,
    this.onRemoveAdsTap,
    this.showRemoveAdsLink = true,
    this.showSlot = true,
  });

  /// Banner ad widget or empty placeholder.
  final Widget? child;

  final VoidCallback? onRemoveAdsTap;

  /// When false, the entire slot (link + ad area) is hidden.
  final bool showSlot;

  final bool showRemoveAdsLink;

  static const double _removeAdsRowHeight = 44;
  static const double _gapBelowLink = 8;

  @override
  Widget build(BuildContext context) {
    if (!showSlot) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final showLink = showRemoveAdsLink && onRemoveAdsTap != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLink)
          Material(
            color: theme.colorScheme.surface,
            child: InkWell(
              onTap: onRemoveAdsTap,
              child: SizedBox(
                height: _removeAdsRowHeight,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Remove ads',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (showLink) const SizedBox(height: _gapBelowLink),
        ClipRect(
          child: SizedBox(
            height: AppThemeConstants.bottomAdHeight,
            width: double.infinity,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
