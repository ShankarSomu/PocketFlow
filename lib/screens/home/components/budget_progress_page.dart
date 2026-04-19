import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/budget.dart';
import '../../../../theme/app_color_scheme.dart';
import '../../../widgets/ui/panel.dart';
import '../../shared/shared.dart';

/// Budget progress tracker showing spending vs limits
class BudgetProgressPage extends StatelessWidget {

  const BudgetProgressPage({
    required this.budgets, required this.categorySpend, super.key,
  });
  final List<Budget> budgets;
  final Map<String, double> categorySpend;

  Color _barColor(BuildContext context, double pct) {
    final appColors = Theme.of(context).extension<AppColorScheme>()!;
    if (pct > 1.0) return appColors.error;
    if (pct >= 0.9) return appColors.warning;
    if (pct >= 0.7) return appColors.primaryVariant;
    return appColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final items = budgets
        .map((b) => (budget: b, spent: categorySpend[b.category] ?? 0.0))
        .toList()
      ..sort((a, b) =>
          (b.spent / (b.budget.limit > 0 ? b.budget.limit : 1))
              .compareTo(a.spent / (a.budget.limit > 0 ? a.budget.limit : 1)));

    final hasOver = items.any((e) => e.spent > e.budget.limit);

    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Budget Progress',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface)),
              const Spacer(),
              if (hasOver)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).extension<AppColorScheme>()!.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Over Budget!',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).extension<AppColorScheme>()!.error)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bar_chart_rounded, size: 40,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text('No budgets set',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                ]),
              ),
            )
          else
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: items.take(5).map((e) {
                  final rawPct = e.budget.limit > 0
                      ? e.spent / e.budget.limit
                      : (e.spent > 0 ? 1.0 : 0.0);
                  final barPct = rawPct.clamp(0.0, 1.0);
                  final color = _barColor(context, rawPct);
                  final isOver = rawPct > 1.0;
                  final remaining = e.budget.limit - e.spent;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isOver)
                            Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Icon(Icons.warning_amber_rounded,
                                  size: 11, color: Theme.of(context).extension<AppColorScheme>()!.error),
                            ),
                          Expanded(
                            child: Text(
                              e.budget.category.isNotEmpty
                                  ? e.budget.category[0].toUpperCase() + e.budget.category.substring(1)
                                  : e.budget.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isOver
                                    ? Theme.of(context).extension<AppColorScheme>()!.error
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${fmt.format(e.spent)} / ${fmt.format(e.budget.limit)}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: barPct),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => Stack(
                          children: [
                            Container(
                              height: 9,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                height: 9,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: isOver
                                      ? [
                                          BoxShadow(
                                            color:
                                                color.withValues(alpha: 0.45),
                                            blurRadius: 6,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isOver
                            ? '⚠ Overspent by ${fmt.format(-remaining)}'
                            : remaining <= 0
                                ? 'Budget fully used'
                                : '${fmt.format(remaining)} remaining · ${(rawPct * 100).toStringAsFixed(0)}% used',
                        style: TextStyle(
                            fontSize: 9,
                            color: isOver
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

