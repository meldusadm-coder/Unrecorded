import 'package:flutter/material.dart';

/// Muted explainer with optional expandable detail.
class HelperText extends StatefulWidget {
  const HelperText({
    super.key,
    required this.text,
    this.expandableDetail,
    this.expandLabel = 'What does this mean?',
  });

  final String text;
  final String? expandableDetail;
  final String expandLabel;

  @override
  State<HelperText> createState() => _HelperTextState();
}

class _HelperTextState extends State<HelperText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: muted,
            height: 1.45,
          ),
        ),
        if (widget.expandableDetail != null) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _expanded ? 'Hide' : widget.expandLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            Text(
              widget.expandableDetail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                height: 1.45,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
