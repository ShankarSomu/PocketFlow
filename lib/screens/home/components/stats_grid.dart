import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class StatsGrid extends StatelessWidget {
  final double savingsRate;
  final double budgetCompliance;
  final int goalsOnTrack;
  final int totalGoals;
  final int activeAccounts;

  const StatsGrid({
    super.key,
    required this.savingsRate,
    required this.budgetCompliance,
    required this.goalsOnTrack,
    required this.totalGoals,
    required this.activeAccounts,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
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
      child: Row(
        children: [
          Expanded(
            child: StatGridCard(
              label: 'Savings Rate',
              value: '${savingsRate.toStringAsFixed(0)}%',
              icon: Icons.savings_outlined,
              gradient: AppTheme.emeraldGradient,
              trend: savingsRate >= 20 ? 'Good' : 'Low',
              trendUp: savingsRate >= 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatGridCard(
              label: 'Budget',
              value: '${budgetCompliance.toStringAsFixed(0)}%',
              icon: Icons.pie_chart_outline,
              gradient: AppTheme.blueGradient,
              trend: budgetCompliance >= 80 ? 'On Track' : 'Review',
              trendUp: budgetCompliance >= 80,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatGridCard(
              label: 'Goals',
              value: '$goalsOnTrack/$totalGoals',
              icon: Icons.flag_outlined,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
              trend: totalGoals > 0 && goalsOnTrack == totalGoals ? 'All' : 'Active',
              trendUp: totalGoals > 0 && goalsOnTrack == totalGoals,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatGridCard(
              label: 'Accounts',
              value: '$activeAccounts',
              icon: Icons.account_balance_wallet_outlined,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.secondary,
                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                ],
              ),
              trend: 'Active',
              trendUp: true,
            ),
          ),
        ],
      ),
    );
  }
}

class StatGridCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final String trend;
  final bool trendUp;

  const StatGridCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.trend,
    required this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                trendUp ? Icons.trending_up : Icons.trending_down,
                size: 12,
                color: trendUp ? AppTheme.emerald : Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 10,
                  color: trendUp ? AppTheme.emerald : Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
