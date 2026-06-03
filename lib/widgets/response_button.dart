import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ResponseButton extends StatelessWidget {
  const ResponseButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (selected) {
      return Semantics(
        selected: true,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }
    return Semantics(
      selected: false,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurfaceVariant,
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
