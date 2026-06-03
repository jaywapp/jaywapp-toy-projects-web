import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppSnackType { success, error, info }

class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    AppSnackType type = AppSnackType.info,
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    final (bg, icon) = _resolve(type);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: bg,
      ),
    );
  }

  static (Color, IconData) _resolve(AppSnackType type) {
    switch (type) {
      case AppSnackType.success:
        return (AppTheme.success, Icons.check_circle_outline);
      case AppSnackType.error:
        return (AppTheme.danger, Icons.error_outline);
      case AppSnackType.info:
        return (AppTheme.primaryDark, Icons.info_outline);
    }
  }
}
