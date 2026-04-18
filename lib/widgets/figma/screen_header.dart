import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../services/time_filter.dart';
import 'global_filter_button.dart';

/// Lightweight top bar used across all main screens (Accounts, Budget, etc.).
/// Shows the [title] on the left and the active time-filter as a tappable pill
/// on the right. Reacts automatically when the global filter changes.
class ScreenHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? subtitle;
  
  const ScreenHeader(
    this.title, {
    this.icon,
    this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
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
