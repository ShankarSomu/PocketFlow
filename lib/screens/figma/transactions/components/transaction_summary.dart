import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/account.dart';
import '../../../../services/theme_service.dart';
import '../../../../theme/app_theme.dart';

/// Gradient card showing net balance and income/expense split
class TransactionSummaryCard extends StatelessWidget {
  final Account? account;
  final double totalIncome;
  final double totalExpense;
  final int transactionCount;
  final NumberFormat fmt;

  const TransactionSummaryCard({
    super.key,
    required this.account,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final net = totalIncome - totalExpense;
    final masked = account != null && account!.last4 != null
        ? '**** ${account!.last4}'
        : '**** ----';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ThemeService.instance.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.credit_card_rounded,
                    color: Theme.of(context).colorScheme.onPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account?.name ?? 'All Accounts',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(masked,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                          fontSize: 12)),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$transactionCount txns',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Net Balance',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(fmt.format(net),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SummaryPill(
                  label: 'Income',
                  amount: fmt.format(totalIncome),
                  icon: Icons.arrow_downward_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryPill(
                  label: 'Expenses',
                  amount: fmt.format(totalExpense),
                  icon: Icons.arrow_upward_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SummaryPill extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  const SummaryPill({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                        fontSize: 11)),
                Text(amount,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
