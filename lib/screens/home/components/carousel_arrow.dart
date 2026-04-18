import 'package:flutter/material.dart';

/// Transparent carousel arrow FAB for navigating between pages
class CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const CarouselArrow({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85), size: 26),
      ),
    );
  }
}
