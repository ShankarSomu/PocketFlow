import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../models/account.dart';
import '../../../../models/transaction.dart' as model;
import '../../../../widgets/confidence_badge.dart';
import 'transaction_helpers.dart';

class TransactionCard extends StatelessWidget {

  const TransactionCard({
    required this.transaction, required this.account, required this.fmt, required this.showDivider, required this.onTap, super.key,
  });
  final model.Transaction transaction;
  final Account? account;
  final NumberFormat fmt;
  final bool showDivider;
  final VoidCallback onTap;

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconForCategory(transaction.category),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayCategory,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                          // Recurring indicator
                          if (transaction.recurringId != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.repeat_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // SMS metadata badges
                      if (transaction.isFromSms ||
                          transaction.merchant != null ||
                          transaction.confidenceScore != null) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Source badge
                            if (transaction.isFromSms)
                              SourceBadge(
                                sourceType: transaction.sourceType,
                                needsReview: transaction.needsReview,
                              ),
                            // Confidence badge - only show if needs review (as info)
                            if (transaction.confidenceScore != null && transaction.needsReview)
                              ConfidenceBadge(score: transaction.confidenceScore!),
                            // Region badge
                            if (transaction.note != null &&
                                transaction.note!.contains('[INDIA]'))
                              const RegionBadge(region: 'INDIA'),
                            if (transaction.note != null &&
                                transaction.note!.contains('[US]'))
                              const RegionBadge(region: 'US'),
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],
                      // Merchant name
                      if (transaction.merchant != null &&
                          transaction.merchant!.isNotEmpty) ...[
                        Text(
                          '@ ${transaction.merchant}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (transaction.note != null &&
                          transaction.note!.isNotEmpty) ...[
                        Text(
                          transaction.note!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
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

