import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction.dart' as model;
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class RecentTransactions extends StatelessWidget {
  final List<model.Transaction> recent;
  final NumberFormat fmt;
  const RecentTransactions({super.key, required this.recent, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
          const SizedBox(height: 14),
          ...recent.map((transaction) {
            final isIncome = transaction.type == 'income';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: (isIncome ? AppTheme.emerald : AppTheme.error).withValues(alpha: 0.15),
                    child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? AppTheme.emerald : AppTheme.error, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(transaction.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slate900)),
                        const SizedBox(height: 3),
                        Text(DateFormat('MMM d').format(transaction.date), style: const TextStyle(fontSize: 12, color: AppTheme.slate500)),
                      ],
                    ),
                  ),
                  Text(
                    '${transaction.type == 'income' ? '+' : '-'}${fmt.format(transaction.amount.abs())}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isIncome ? AppTheme.emerald : AppTheme.error),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
