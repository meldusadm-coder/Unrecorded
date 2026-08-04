import 'package:flutter/material.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

/// Semantic tone for [PrimaryActionButton] (preferred over arbitrary [color]).
enum PrimaryActionTone {
  primary,
  danger,
  neutral,
}

/// A large, prominent call-to-action button.
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? color;
  final PrimaryActionTone? tone;

  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.color,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = color ??
        switch (tone) {
          PrimaryActionTone.danger => UnrecordedColors.danger,
          PrimaryActionTone.neutral => UnrecordedColors.muted,
          PrimaryActionTone.primary || null => theme.colorScheme.primary,
        };

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
