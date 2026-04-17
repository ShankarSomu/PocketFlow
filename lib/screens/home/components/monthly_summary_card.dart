import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import 'stat_card.dart';

class MonthlySummaryCard extends StatelessWidget {
  final double income, expenses, net;
  final NumberFormat fmt;
  final bool isProjected;
  const MonthlySummaryCard(
      {super.key,
      required this.income,
      required this.expenses,
      required this.net,
      required this.fmt,
      this.isProjected = false});

  @override
  Widget build(BuildContext context) {
    final spentRatio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate900,
                  ),
                ),
                if (isProjected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Projected',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Income',
                    value: income,
                    icon: Icons.arrow_downward_rounded,
                    gradient: AppTheme.emeraldGradient,
                    fmt: fmt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Expenses',
                    value: expenses,
                    icon: Icons.arrow_upward_rounded,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.error,
                        Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                      ],
                    ),
                    fmt: fmt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Net',
                    value: net,
                    icon: net >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    gradient: net >= 0 ? AppTheme.blueGradient : LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary,
                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                      ],
                    ),
                    fmt: fmt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: spentRatio,
                minHeight: 12,
                backgroundColor: AppTheme.emerald.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  expenses > income ? AppTheme.error : AppTheme.emerald,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              income > 0
                  ? '${(spentRatio * 100).toStringAsFixed(0)}% of income spent'
                  : 'No income recorded',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
