import 'package:flutter/material.dart';
import 'global_filter_button.dart';

/// Mini circular FAB that opens the global time-filter sheet.
/// Place inside a [Stack] body via [Positioned(bottom: 16, left: 16)].
class CalendarFab extends StatelessWidget {
  const CalendarFab({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showTimeFilterSheet(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.calendar_today_rounded,
            color: Theme.of(context).colorScheme.onPrimary, size: 18),
      ),
    );
  }
}
