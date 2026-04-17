import 'package:flutter/material.dart';

/// A small circular badge with a gradient background and an emoji/icon label.
class FigmaIconCircle extends StatelessWidget {
  final String label;
  final Gradient gradient;
  final double size;
  const FigmaIconCircle({super.key, required this.label, required this.gradient, this.size = 44});

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
