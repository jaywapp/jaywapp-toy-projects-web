import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 10,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final base = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF222B36) : const Color(0xFFE9EDF3);
        final hi = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2B3746) : const Color(0xFFF6F8FB);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - (t * 2), -0.2),
              end: Alignment(1 + (t * 2), 0.2),
              colors: [base, hi, base],
              stops: const [0.25, 0.5, 0.75],
              transform: GradientRotation(math.pi / 12),
            ),
          ),
        );
      },
    );
  }
}
