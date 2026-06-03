import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF1E90FF);
  static const Color primaryDark = Color(0xFF1873CC);
  static const Color primaryLight = Color(0xFFE8F3FF);
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color danger = Color(0xFFE74C3C);
  static const Color darkBackground = Color(0xFF0F141A);
  static const Color darkSurface = Color(0xFF151B22);
  static const Color darkBorder = Color(0xFF243040);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: primary,
      surface: surface,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE3E8EF)),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        selectedIconTheme: IconThemeData(size: 22),
        unselectedIconTheme: IconThemeData(size: 22),
        showUnselectedLabels: true,
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.white,
      secondary: primary,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: darkSurface,
      onSurface: Color(0xFFE6EDF5),
      onSurfaceVariant: Color(0xFFB5C2D2),
      outline: darkBorder,
      shadow: Colors.black,
      inverseSurface: Colors.white,
      onInverseSurface: Colors.black,
      inversePrimary: primaryLight,
      tertiary: warning,
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFF4C340C),
      onTertiaryContainer: Color(0xFFFFE3B8),
      primaryContainer: Color(0xFF193655),
      onPrimaryContainer: Color(0xFFD7E8FF),
      secondaryContainer: Color(0xFF183654),
      onSecondaryContainer: Color(0xFFD7E8FF),
      errorContainer: Color(0xFF5A2020),
      onErrorContainer: Color(0xFFFFD7D5),
      surfaceDim: Color(0xFF0C1116),
      surfaceBright: Color(0xFF1A222C),
      surfaceContainerLowest: Color(0xFF0A0F14),
      surfaceContainerLow: Color(0xFF10161C),
      surfaceContainer: Color(0xFF151B22),
      surfaceContainerHigh: Color(0xFF1B2430),
      surfaceContainerHighest: Color(0xFF232E3B),
      outlineVariant: Color(0xFF2A3645),
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Color(0xFFE6EDF5),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF8D98A7),
        selectedIconTheme: IconThemeData(size: 22),
        unselectedIconTheme: IconThemeData(size: 22),
        showUnselectedLabels: true,
      ),
    );
  }
}
