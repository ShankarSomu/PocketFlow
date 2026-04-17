import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction.dart' as model;
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

class RecentTransactionsQuick extends StatelessWidget {
  final List<model.Transaction> recent;
  final NumberFormat fmt;

  const RecentTransactionsQuick({super.key, required this.recent, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppTheme.emeraldGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.onPrimary, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recent',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No transactions',
                  style: TextStyle(color: AppTheme.slate400, fontSize: 12),
                ),
              ),
            )
          else
            ...recent.take(5).map((t) {
              final isIncome = t.type == 'income';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (isIncome ? AppTheme.emerald : AppTheme.error).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 12,
                        color: isIncome ? AppTheme.emerald : AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.category,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.slate700,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            DateFormat('MMM d').format(t.date),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      fmt.format(t.amount),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isIncome ? AppTheme.emerald : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
