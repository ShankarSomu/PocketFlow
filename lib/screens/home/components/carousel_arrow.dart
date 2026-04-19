import 'package:flutter/material.dart';

/// Transparent carousel arrow FAB for navigating between pages
class CarouselArrow extends StatelessWidget {

  const CarouselArrow({
    required this.icon, required this.onTap, super.key,
  });
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85), size: 26),
      ),
    );
  }
}

