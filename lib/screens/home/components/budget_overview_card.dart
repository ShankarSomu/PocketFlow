import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/budget.dart';

class BudgetOverviewCard extends StatelessWidget {
  final List<Budget> budgets;
  final Map<String, double> spent;
  final NumberFormat fmt;
  const BudgetOverviewCard(
      {super.key, required this.budgets, required this.spent, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final overCount = budgets.where((b) => (spent[b.category] ?? 0) > b.limit).length;
    final underCount = budgets.length - overCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Budget Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(children: [
              if (overCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('$overCount over',
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 11)),
                ),
                const SizedBox(width: 6),
              ],
              if (underCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('$underCount on track',
                      style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontSize: 11)),
                ),
            ]),
          ]),
          const SizedBox(height: 12),
          ...budgets.take(4).map((b) {
            final s = spent[b.category] ?? 0;
            final ratio = (s / b.limit).clamp(0.0, 1.0);
            final over = s > b.limit;
            final color = over
                ? Theme.of(context).colorScheme.error
                : ratio > 0.8
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.tertiary;
            final diff = (b.limit - s).abs();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(b.category,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Row(children: [
                      Icon(
                        over ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: over ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        over
                            ? '${fmt.format(diff)} over'
                            : '${fmt.format(diff)} left',
                        style: TextStyle(
                            fontSize: 11,
                            color: over ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.3), width: 0.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${fmt.format(s)} spent',
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                    Text('of ${fmt.format(b.limit)} budget',
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  ]),
                ],
              ),
            );
          }),
          if (budgets.length > 4)
            Text('+ ${budgets.length - 4} more budgets',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }
}
