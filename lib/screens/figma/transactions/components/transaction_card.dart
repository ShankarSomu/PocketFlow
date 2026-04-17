import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/transaction.dart' as model;
import '../../../../models/account.dart';
import 'transaction_helpers.dart';

class TransactionCard extends StatelessWidget {
  final model.Transaction transaction;
  final Account? account;
  final NumberFormat fmt;
  final bool showDivider;
  final VoidCallback onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.account,
    required this.fmt,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final color = isIncome
        ? Theme.of(context).colorScheme.primary
        : colorForCategory(context, transaction.category);
    final displayCategory = transaction.category.isNotEmpty
        ? transaction.category[0].toUpperCase() +
            transaction.category.substring(1)
        : 'Uncategorized';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconForCategory(transaction.category),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayCategory,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      if (transaction.note != null &&
                          transaction.note!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          transaction.note!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${isIncome ? '+' : '-'}${fmt.format(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isIncome
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 56),
                child: Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
          ],
        ),
      ),
    );
  }
}
