import 'package:flutter/material.dart';

/// Brand palette from the Unrecorded design kit.
abstract final class UnrecordedColors {
  static const Color primary = Color(0xFF5B4DFF);
  static const Color primaryDark = Color(0xFF3F36C9);
  static const Color accent = Color(0xFF7C3AED);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color surface = Color(0xFFF6F6FA);
  static const Color background = Color(0xFF0F1117);
  static const Color onSurface = Color(0xFF2B2D42);
}

/// Material [ColorScheme] built from [UnrecordedColors].
abstract final class UnrecordedColorScheme {
  static ColorScheme light() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: UnrecordedColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE8E6FF),
      onPrimaryContainer: UnrecordedColors.primaryDark,
      secondary: UnrecordedColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEDE9FE),
      onSecondaryContainer: UnrecordedColors.accent,
      tertiary: UnrecordedColors.info,
      onTertiary: Colors.white,
      error: UnrecordedColors.danger,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: UnrecordedColors.danger,
      surface: UnrecordedColors.surface,
      onSurface: UnrecordedColors.onSurface,
      onSurfaceVariant: Color(0xFF6B7280),
      outline: Color(0xFFD1D5DB),
      outlineVariant: Color(0xFFE5E7EB),
      shadow: Colors.black26,
      scrim: Colors.black54,
      inverseSurface: UnrecordedColors.onSurface,
      onInverseSurface: UnrecordedColors.surface,
      inversePrimary: Color(0xFFB4ABFF),
      surfaceTint: UnrecordedColors.primary,
      surfaceContainerHighest: Color(0xFFECECF2),
    );
  }

  static ColorScheme dark() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFB4ABFF),
      onPrimary: UnrecordedColors.primaryDark,
      primaryContainer: UnrecordedColors.primaryDark,
      onPrimaryContainer: Color(0xFFE8E6FF),
      secondary: Color(0xFFC4B5FD),
      onSecondary: UnrecordedColors.accent,
      secondaryContainer: UnrecordedColors.accent,
      onSecondaryContainer: Color(0xFFEDE9FE),
      tertiary: UnrecordedColors.info,
      onTertiary: Colors.white,
      error: Color(0xFFFCA5A5),
      onError: UnrecordedColors.danger,
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: Color(0xFF1A1D26),
      onSurface: Color(0xFFE5E7EB),
      onSurfaceVariant: Color(0xFF9CA3AF),
      outline: Color(0xFF4B5563),
      outlineVariant: Color(0xFF374151),
      shadow: Colors.black,
      scrim: Colors.black87,
      inverseSurface: UnrecordedColors.surface,
      onInverseSurface: UnrecordedColors.onSurface,
      inversePrimary: UnrecordedColors.primary,
      surfaceTint: UnrecordedColors.primary,
      surfaceContainerHighest: Color(0xFF2B2D42),
    );
  }
}

/// Shared visual constants for consistent styling.
abstract final class AppThemeConstants {
  static const double cardRadius = 12;
  static const double helperSpacing = 8;

  /// Highlight for suspicious signal cards (light mode).
  static const Color suspiciousBackgroundLight = Color(0xFFFFF7ED);
  static const Color suspiciousBorderLight = UnrecordedColors.warning;

  /// Highlight for suspicious signal cards (dark mode).
  static const Color suspiciousBackgroundDark = Color(0xFF3E2723);
  static const Color suspiciousBorderDark = Color(0xFFFFB74D);

  static const double bottomAdHeight = 56;
}
