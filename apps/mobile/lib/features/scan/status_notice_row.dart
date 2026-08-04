import 'package:flutter/material.dart';

import 'protection_accent.dart';

/// Compact contextual notice: icon + one short sentence + optional action.
class StatusNoticeRow extends StatelessWidget {
  const StatusNoticeRow({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.accent = ProtectionAccent.info,
    this.icon,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ProtectionAccent accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = accent.resolve(context);

    return Semantics(
      container: true,
      label: message,
      child: Material(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon ?? Icons.info_outline, color: colour, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                    if (actionLabel != null && onAction != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
