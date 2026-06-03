import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_card.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.title,
    required this.value,
    this.accentColor,
    this.onTap,
  });

  final String title;
  final String value;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.primary;
    return Semantics(
      label: '$title: $value',
      button: onTap != null,
      child: AppCard(
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 132,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
