import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {

  const GlassCard({
    required this.child, super.key,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.color,
    this.border,
    this.boxShadow,
  });
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final Color? color;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.92)
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0.85);
    final defaultBorder = isDark
        ? Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08))
        : Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2));

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? defaultColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? defaultBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

