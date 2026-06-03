import 'package:flutter/material.dart';

class AnimatedListEntry extends StatelessWidget {
  const AnimatedListEntry({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, t, c) {
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: c),
        );
      },
      child: child,
    );
  }
}
