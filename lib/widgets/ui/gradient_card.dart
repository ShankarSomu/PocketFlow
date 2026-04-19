import 'package:flutter/material.dart';

/// A card with a gradient background and soft shadow.
class GradientCard extends StatelessWidget {
  const GradientCard({
    required this.child, required this.gradient, super.key,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
  });
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

