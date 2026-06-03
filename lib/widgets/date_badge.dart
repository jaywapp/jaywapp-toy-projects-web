import 'package:flutter/material.dart';

class DateBadge extends StatelessWidget {
  const DateBadge({
    super.key,
    required this.text,
    this.icon = Icons.schedule,
    this.past = false,
  });

  final String text;
  final IconData icon;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = past ? colorScheme.onSurfaceVariant : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: past
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}
