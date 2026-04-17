import 'package:flutter/material.dart';

/// A rounded linear progress indicator with custom color.
class FigmaProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const FigmaProgressBar({super.key, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LinearProgressIndicator(
        minHeight: 10,
        value: value.clamp(0, 1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        backgroundColor: color.withOpacity(0.18),
      ),
    );
  }
}
