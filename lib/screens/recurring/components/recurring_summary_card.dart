import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/recurring_transaction.dart';
import '../../../services/theme_service.dart';
import '../../../theme/app_theme.dart';

/// Converts any frequency to its monthly equivalent multiplier.
double _monthlyMultiplier(String frequency) {
  switch (frequency) {
    case 'daily':
      return 30.44;
    case 'weekly':
      return 4.33;
    case 'biweekly':
      return 2.17;
    case 'monthly':
      return 1.0;
    case 'half-yearly':
      return 1 / 6;
    case 'yearly':
      return 1 / 12;
    case 'once':
      return 0.0; // one-time, doesn't count toward monthly
    default:
      return 1.0;
  }
}

/// Frequency-aware monthly total for a list of recurring items.
double monthlyEquivalent(List<RecurringTransaction> items) {
  return items.fold(0.0, (sum, i) => sum + i.amount * _monthlyMultiplier(i.frequency));
}

class RecurringSummaryCard extends StatelessWidget {
  const RecurringSummaryCard({
    required this.activeItems,
    required this.pausedCount,
    required this.fmt,
    super.key,
  });

  final List<RecurringTransaction> activeItems;
  final int pausedCount;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final expenses = activeItems.where((i) => i.type == 'expense' || i.type == 'transfer' || i.type == 'goal').toList();
    final income = activeItems.where((i) => i.type == 'income').toList();
    final totalExpense = monthlyEquivalent(expenses);
    final totalIncome = monthlyEquivalent(income);
    final net = totalIncome - totalExpense;
    final hasIncome = totalIncome > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ThemeService.instance.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly equivalent',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          // Income / Expense row
          Row(
            children: [
              if (hasIncome) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      fmt.format(totalIncome),
                      style: TextStyle(
                        color: Colors.greenAccent.shade100,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '–',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5),
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasIncome ? 'Out' : 'Expenses',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    fmt.format(totalExpense),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: hasIncome ? 20 : 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              if (hasIncome) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '=',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5),
                      fontSize: 20,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${net >= 0 ? '+' : ''}${fmt.format(net)}',
                      style: TextStyle(
                        color: net >= 0 ? Colors.greenAccent.shade100 : Colors.redAccent.shade100,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'Active',
                  value: '${activeItems.length}',
                  icon: Icons.play_circle_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Paused',
                  value: '$pausedCount',
                  icon: Icons.pause_circle_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 12),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
