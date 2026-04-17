import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../services/theme_service.dart';
import '../../../../theme/app_theme.dart';
import '../../accounts_screen.dart';
import '../../savings_screen.dart';
import '../../transactions_screen.dart';

/// Stats row showing net balance, savings rate, income, and expenses
class HomeStatsRow extends StatelessWidget {
  final double totalBalance;
  final double income;
  final double expenses;
  final double prevIncome;
  final double prevExpenses;
  final double savingsRate;

  const HomeStatsRow({
    super.key,
    required this.totalBalance,
    required this.income,
    required this.expenses,
    required this.prevIncome,
    required this.prevExpenses,
    required this.savingsRate,
  });

  String _pctChange(double current, double previous) {
    if (previous == 0) return current > 0 ? '+100%' : '—';
    final pct = (current - previous) / previous * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  Widget _buildMiniStat(
    BuildContext context,
    String title,
    String value,
    String change,
    Color accent, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: ThemeService.instance.cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: ThemeService.instance.primaryShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                        fontWeight: FontWeight.w500)),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.trending_up, color: accent, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onPrimary)),
            const SizedBox(height: 3),
            Text(change,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final incomeChg = _pctChange(income, prevIncome);
    final expChg = _pctChange(expenses, prevExpenses);
    final prevSavings = prevIncome <= 0
        ? 0.0
        : ((prevIncome - prevExpenses) / prevIncome).clamp(0.0, 1.0);
    final savingsDiff = ((savingsRate - prevSavings) * 100);
    final savingsChg =
        '${savingsDiff >= 0 ? '+' : ''}${savingsDiff.toStringAsFixed(1)}pp';
    final netBalanceChg = totalBalance >= 0 ? 'Total assets' : 'Net negative';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                context,
                'Net Balance',
                fmt.format(totalBalance),
                netBalanceChg,
                ThemeService.instance.primaryColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountsScreen()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStat(
                context,
                'Savings Rate',
                '${(savingsRate * 100).toStringAsFixed(0)}%',
                savingsChg,
                ThemeService.instance.primaryColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavingsScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMiniStat(
                context,
                'Income',
                fmt.format(income),
                incomeChg,
                ThemeService.instance.primaryColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const TransactionsScreen(initialFilterType: 'income')),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniStat(
                context,
                'Expenses',
                fmt.format(expenses),
                expChg,
                AppTheme.error,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TransactionsScreen(
                          initialFilterType: 'expense')),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
