import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (icon != null) ...[
                ExcludeSemantics(child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(width: 6),
              ],
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        if (actionLabel != null && onActionTap != null)
          TextButton(onPressed: onActionTap, child: Text(actionLabel!)),
      ],
    );
  }
}
