import 'package:flutter/material.dart';

/// A translucent panel with a border and shadow, adapting to light/dark themes.
class FigmaPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const FigmaPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surface.withOpacity(0.95)
            : Theme.of(context).colorScheme.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.08)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
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
