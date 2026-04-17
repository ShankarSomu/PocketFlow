import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/transaction.dart' as model;
import '../../../../models/account.dart';
import 'transaction_card.dart';

/// Date section - date group header + list of transaction cards in a white card
class TransactionDateSection extends StatelessWidget {
  final String dateLabel;
  final List<model.Transaction> transactions;
  final List<Account> accounts;
  final NumberFormat fmt;
  final void Function(model.Transaction) onTap;

  const TransactionDateSection({
    super.key,
    required this.dateLabel,
    required this.transactions,
    required this.accounts,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            dateLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: transactions.asMap().entries.map((e) {
              final isLast = e.key == transactions.length - 1;
              return TransactionCard(
                transaction: e.value,
                account: accounts
                    .where((a) => a.id == e.value.accountId)
                    .firstOrNull,
                fmt: fmt,
                showDivider: !isLast,
                onTap: () => onTap(e.value),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
