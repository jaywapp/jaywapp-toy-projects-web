import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF6D28D9);
  static const Color primaryDark = Color(0xFF4C1D95);
  static const Color primaryLight = Color(0xFF8B5CF6);

  static const Color surface = Color(0xFF1E1B4B);
  static const Color background = Color(0xFF0F0A1E);

  static const Color onPrimary = Colors.white;
  static const Color onBackground = Colors.white;
  static const Color onSurface = Colors.white;

  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFAA99CC);
  static const Color textHint = Color(0xFF6B5B8A);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}
