import 'package:flutter/material.dart';

/// A small circular badge with a gradient background and an emoji/icon label.
class IconCircle extends StatelessWidget {
  const IconCircle({required this.label, required this.gradient, super.key, this.size = 44});
  final String label;
  final Gradient gradient;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(fontSize: 20),
      ),
    );
  }
}
