import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Stats card showing a metric with value and optional change percentage
class StatsCard extends StatelessWidget {

  const StatsCard({
    required this.title, required this.value, super.key,
    this.valuePrefix,
    this.valueSuffix,
    this.percentChange,
    this.icon,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
  });
  final String title;
  final double value;
  final String? valuePrefix;
  final String? valueSuffix;
  final String? percentChange;
  final IconData? icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: valuePrefix ?? '\$', decimalDigits: 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (iconColor ?? theme.colorScheme.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (percentChange != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: percentChange!.startsWith('+')
                          ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1)
                          : percentChange!.startsWith('-')
                              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      percentChange!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: percentChange!.startsWith('+')
                            ? Theme.of(context).colorScheme.tertiary
                            : percentChange!.startsWith('-')
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              valueSuffix != null
                  ? '${fmt.format(value)}$valueSuffix'
                  : fmt.format(value),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid layout for multiple stat cards
class StatsGrid extends StatelessWidget {

  const StatsGrid({
    required this.cards, super.key,
    this.crossAxisCount = 2,
    this.spacing = 12,
  });
  final List<StatsCard> cards;
  final int crossAxisCount;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: 1.5,
      children: cards,
    );
  }
}

