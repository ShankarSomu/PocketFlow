import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction.dart' as model;
import '../../../theme/app_theme.dart';

class RecentCard extends StatelessWidget {
  final List<model.Transaction> recent;
  final NumberFormat fmt;
  const RecentCard({super.key, required this.recent, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recent Transactions',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ...recent.map((t) {
            final isIncome = t.type == 'income';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: (isIncome ? AppTheme.emerald : AppTheme.error).withValues(alpha: 0.15),
                child: Icon(
                  isIncome
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 14,
                  color: isIncome ? AppTheme.emerald : AppTheme.error,
                ),
              ),
              title: Text(t.category,
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                  DateFormat('MMM d').format(t.date),
                  style: const TextStyle(fontSize: 11)),
              trailing: Text(fmt.format(t.amount),
                  style: TextStyle(
                      color: isIncome ? AppTheme.emerald : AppTheme.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            );
          }),
        ]),
      ),
    );
  }
}
