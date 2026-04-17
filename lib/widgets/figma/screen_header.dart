import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../services/time_filter.dart';
import 'global_filter_button.dart';

/// Lightweight top bar used across all main screens (Accounts, Budget, etc.).
/// Shows the [title] on the left and the active time-filter as a tappable pill
/// on the right. Reacts automatically when the global filter changes.
class ScreenHeader extends StatelessWidget {
  final String title;
  const ScreenHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Reactive filter badge – tapping opens the picker
          AnimatedBuilder(
            animation: appTimeFilter,
            builder: (context, _) => GestureDetector(
              onTap: () => showTimeFilterSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: ThemeService.instance.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: ThemeService.instance.primaryShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 12, color: Theme.of(context).colorScheme.onPrimary),
                    const SizedBox(width: 5),
                    Text(
                      appTimeFilter.current.shortLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14, color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
