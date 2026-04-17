import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class AccountHealthCard extends StatelessWidget {
  final double savingsRate;
  final double budgetCompliance;
  final int goalsOnTrack;
  final int totalGoals;

  const AccountHealthCard({
    super.key,
    required this.savingsRate,
    required this.budgetCompliance,
    required this.goalsOnTrack,
    required this.totalGoals,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: child,
          ),
        );
      },
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.emeraldGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.health_and_safety, color: AppTheme.slate200, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Account Health',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.slate200,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: HealthMetric(
                    label: 'Savings Rate',
                    value: '${savingsRate.toStringAsFixed(0)}%',
                    icon: Icons.savings_outlined,
                    color: savingsRate >= 20 ? AppTheme.emerald : Theme.of(context).colorScheme.secondary,
                    status: savingsRate >= 20 ? 'Good' : 'Low',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HealthMetric(
                    label: 'Budget',
                    value: '${budgetCompliance.toStringAsFixed(0)}%',
                    icon: Icons.pie_chart_outline,
                    color: budgetCompliance >= 80 ? AppTheme.emerald : Theme.of(context).colorScheme.secondary,
                    status: budgetCompliance >= 80 ? 'On Track' : 'Review',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HealthMetric(
                    label: 'Goals',
                    value: '$goalsOnTrack/$totalGoals',
                    icon: Icons.flag_outlined,
                    color: totalGoals > 0 && goalsOnTrack == totalGoals ? AppTheme.emerald : AppTheme.indigo,
                    status: totalGoals > 0 && goalsOnTrack == totalGoals ? 'All' : 'Active',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HealthMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String status;

  const HealthMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.slate600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
