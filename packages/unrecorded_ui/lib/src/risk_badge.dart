import 'package:flutter/material.dart';
import 'package:unrecorded_core/unrecorded_core.dart';

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
          Icon(Icons.shield_outlined, size: 16, color: _color),
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

  Color get _color => switch (level) {
    RiskLevel.low => const Color(0xFF4CAF50),
    RiskLevel.medium => const Color(0xFFFFA726),
    RiskLevel.high => const Color(0xFFEF5350),
  };

  String get _label => switch (level) {
    RiskLevel.low => 'Low risk',
    RiskLevel.medium => 'Medium risk',
    RiskLevel.high => 'High risk',
  };
}
