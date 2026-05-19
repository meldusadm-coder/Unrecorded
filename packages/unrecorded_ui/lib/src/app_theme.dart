import 'package:flutter/material.dart';

/// Shared visual constants for consistent styling.
abstract final class AppThemeConstants {
  static const double cardRadius = 12;
  static const double helperSpacing = 8;

  /// Highlight for suspicious signal cards (light mode).
  static const Color suspiciousBackgroundLight = Color(0xFFFFF3E0);
  static const Color suspiciousBorderLight = Color(0xFFFFA726);

  /// Highlight for suspicious signal cards (dark mode).
  static const Color suspiciousBackgroundDark = Color(0xFF3E2723);
  static const Color suspiciousBorderDark = Color(0xFFFFB74D);

  static const double bottomAdHeight = 56;
}
