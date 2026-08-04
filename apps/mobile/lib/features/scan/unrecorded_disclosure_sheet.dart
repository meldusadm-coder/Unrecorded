import 'package:flutter/material.dart';

/// Shared progressive-disclosure bottom sheet for short supporting copy.
class UnrecordedDisclosureSheet {
  UnrecordedDisclosureSheet._();

  static Future<void> show({
    required BuildContext context,
    required String title,
    required Widget body,
    String? semanticLabel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Semantics(
          label: semanticLabel ?? title,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  body,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Compact text-link trigger used across screens.
  static Widget trigger({
    required BuildContext context,
    required String label,
    required String sheetTitle,
    required Widget sheetBody,
    Key? key,
  }) {
    return Semantics(
      button: true,
      label: label,
      hint: 'Opens more information',
      child: TextButton(
        key: key,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => show(
          context: context,
          title: sheetTitle,
          body: sheetBody,
        ),
        child: Text('$label ›'),
      ),
    );
  }
}

/// Collapsed accordion row used on Help / alert-explanation screens.
class UnrecordedDisclosureAccordion extends StatelessWidget {
  const UnrecordedDisclosureAccordion({
    super.key,
    required this.title,
    required this.body,
    this.initiallyExpanded = false,
  });

  final String title;
  final String body;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(title, style: theme.textTheme.titleSmall),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}
