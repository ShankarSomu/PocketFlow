import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/recurring_transaction.dart';

class RecurringOverviewCard extends StatelessWidget {
  final List<RecurringTransaction> recurring;
  final NumberFormat fmt;
  const RecurringOverviewCard(
      {super.key, required this.recurring, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = recurring
        .where((r) => r.isActive)
        .toList()
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    final totalMonthlyExpense = recurring
        .where((r) => r.isActive && r.type == 'expense')
        .fold(0.0, (s, r) => s + r.amount);
    final totalMonthlyIncome = recurring
        .where((r) => r.isActive && r.type == 'income')
        .fold(0.0, (s, r) => s + r.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recurring',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(children: [
              Icon(Icons.arrow_downward, size: 12, color: Theme.of(context).colorScheme.tertiary),
              Text(fmt.format(totalMonthlyIncome),
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.tertiary)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_upward, size: 12, color: Theme.of(context).colorScheme.error),
              Text(fmt.format(totalMonthlyExpense),
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error)),
            ]),
          ]),
          const SizedBox(height: 10),
          ...upcoming.take(4).map((r) {
            final due = DateTime(r.nextDueDate.year,
                r.nextDueDate.month, r.nextDueDate.day);
            final daysUntil = due.difference(today).inDays;
            final isDue = daysUntil <= 0;
            final isSoon = daysUntil <= 3 && daysUntil > 0;
            final isIncome = r.type == 'income';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: (isIncome ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error)
                      .withValues(alpha: 0.12),
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 12,
                    color: isIncome ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.category,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(
                        r.frequency[0].toUpperCase() +
                            r.frequency.substring(1),
                        style: TextStyle(
                            fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt.format(r.amount),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isIncome ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isDue
                            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                            : isSoon
                                ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isDue
                            ? 'Due today'
                            : isSoon
                                ? 'In $daysUntil days'
                                : DateFormat('MMM d').format(r.nextDueDate),
                        style: TextStyle(
                            fontSize: 10,
                            color: isDue
                                ? Theme.of(context).colorScheme.error
                                : isSoon
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
              ]),
            );
          }),
          if (upcoming.length > 4)
            Text('+ ${upcoming.length - 4} more',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }
}
