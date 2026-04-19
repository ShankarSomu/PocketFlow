import 'package:flutter/material.dart';

/// A rounded linear progress indicator with custom color.
class ProgressBar extends StatelessWidget {
  const ProgressBar({required this.value, required this.color, super.key});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LinearProgressIndicator(
        minHeight: 10,
        value: value.clamp(0, 1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        backgroundColor: color.withValues(alpha: 0.18),
      ),
    );
  }
}

