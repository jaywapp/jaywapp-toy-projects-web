import 'package:flutter/material.dart';

class AppLoadingButton extends StatefulWidget {
  const AppLoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  @override
  State<AppLoadingButton> createState() => _AppLoadingButtonState();
}

class _AppLoadingButtonState extends State<AppLoadingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final canTap = widget.enabled && !widget.loading && widget.onPressed != null;
    return GestureDetector(
      onTapDown: canTap ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: canTap ? () => setState(() => _pressed = false) : null,
      onTapUp: canTap ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.97 : 1,
        child: ElevatedButton(
          onPressed: canTap ? widget.onPressed : null,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: widget.loading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(widget.label, key: const ValueKey('label')),
          ),
        ),
      ),
    );
  }
}
