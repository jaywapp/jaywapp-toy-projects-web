import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusBadgeTone { success, warning, danger, primary }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusBadgeTone.primary,
  });

  final String label;
  final StatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteByTone(context, tone);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: palette.$1,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.$2,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  (Color, Color) _paletteByTone(BuildContext context, StatusBadgeTone tone) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (tone) {
      case StatusBadgeTone.success:
        return (dark ? const Color(0xFF1A3A2A) : const Color(0xFFEAF9F0), AppTheme.success);
      case StatusBadgeTone.warning:
        return (dark ? const Color(0xFF4C340C) : const Color(0xFFFFF5E9), AppTheme.warning);
      case StatusBadgeTone.danger:
        return (dark ? const Color(0xFF5A2020) : const Color(0xFFFDEDEC), AppTheme.danger);
      case StatusBadgeTone.primary:
        return (dark ? const Color(0xFF193655) : AppTheme.primaryLight, dark ? const Color(0xFFD7E8FF) : AppTheme.primaryDark);
    }
  }
}
