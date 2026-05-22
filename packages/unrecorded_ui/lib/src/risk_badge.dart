import 'package:flutter/material.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

import 'app_theme.dart';
import 'unrecorded_icon.dart';

/// Displays the current [RiskLevel] as a compact coloured badge.
class RiskBadge extends StatelessWidget {
  final RiskLevel level;

  const RiskBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UnrecordedIcon(asset: _iconAsset, size: 16, color: _color),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  UnrecordedIconAsset get _iconAsset => switch (level) {
        RiskLevel.low => UnrecordedIconAsset.riskLow,
        RiskLevel.medium => UnrecordedIconAsset.riskMedium,
        RiskLevel.high => UnrecordedIconAsset.riskHigh,
      };

  Color get _color => switch (level) {
        RiskLevel.low => UnrecordedColors.success,
        RiskLevel.medium => UnrecordedColors.warning,
        RiskLevel.high => UnrecordedColors.danger,
      };

  String get _label => labelFor(level);

  /// Short user-facing label for a [RiskLevel] (notifications, copy).
  static String labelFor(RiskLevel level) => switch (level) {
        RiskLevel.low => 'Low risk',
        RiskLevel.medium => 'Medium risk',
        RiskLevel.high => 'High risk',
      };
}
