import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _visible ? 1 : 0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1D2631) : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExcludeSemantics(child: Icon(widget.icon, color: dark ? const Color(0xFF77879B) : Colors.grey.shade400, size: 36)),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: dark ? const Color(0xFF96A3B3) : Colors.black54,
                    ),
                textAlign: TextAlign.center,
              ),
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  onPressed: widget.onAction,
                  child: Text(widget.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
