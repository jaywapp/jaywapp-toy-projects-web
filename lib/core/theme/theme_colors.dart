import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 현재 테마(다크/라이트)에 맞는 색상을 반환하는 확장
extension ThemeColorsExtension on BuildContext {
  ThemeColors get appColors {
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? ThemeColors.dark() : ThemeColors.light();
  }
}

class ThemeColors {
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color surface;
  final Color background;
  final Color onSurface;

  const ThemeColors._({
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.surface,
    required this.background,
    required this.onSurface,
  });

  factory ThemeColors.dark() => const ThemeColors._(
        textPrimary: AppColors.textPrimary,       // white
        textSecondary: AppColors.textSecondary,   // #AA99CC
        textHint: AppColors.textHint,             // #6B5B8A
        surface: AppColors.surface,               // #1E1B4B
        background: AppColors.background,         // #0F0A1E
        onSurface: AppColors.onSurface,           // white
      );

  factory ThemeColors.light() => const ThemeColors._(
        textPrimary: Color(0xFF1A1A2E),
        textSecondary: Color(0xFF555577),
        textHint: Color(0xFF9999BB),
        surface: Color(0xFFF0EEF8),
        background: Colors.white,
        onSurface: Color(0xFF1A1A2E),
      );
}
