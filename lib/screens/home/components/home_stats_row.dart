import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../services/theme_service.dart';
import '../../../../theme/app_color_scheme.dart';
import '../../accounts/accounts_screen.dart';
import '../../savings/savings_screen.dart';
import '../../transactions/transactions_screen.dart';

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
    Gradient? gradient,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: gradient ?? ThemeService.instance.cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.trending_up, color: Colors.white.withOpacity(0.9), size: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 3),
            Text(change,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorScheme>()!;
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

    // Use theme primary color for all cards with subtle variations
    final primaryColor = ThemeService.instance.primaryColor;
    final primaryDark = ThemeService.instance.primaryDark;

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
                primaryColor,
                gradient: LinearGradient(
                  colors: [primaryColor, primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                primaryColor,
                gradient: LinearGradient(
                  colors: [primaryColor.withOpacity(0.85), primaryDark.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                appColors.success,
                gradient: LinearGradient(
                  colors: [appColors.success, appColors.success.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                appColors.error,
                gradient: LinearGradient(
                  colors: [appColors.error, appColors.error.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
