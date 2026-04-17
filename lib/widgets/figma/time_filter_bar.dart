import 'package:flutter/material.dart';
import '../../services/time_filter.dart';

/// A horizontal bar for selecting the global time filter.
class TimeFilterBar extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  const TimeFilterBar({super.key, this.padding = const EdgeInsets.symmetric(vertical: 8)});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appTimeFilter,
      builder: (context, _) {
        final current = appTimeFilter.current;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                for (final kind in TimeFilterKind.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(kind.displayName),
                      selected: current.kind == kind,
                      onSelected: (selected) {
                        if (selected) appTimeFilter.select(kind);
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: current.kind == kind
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
