import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/account.dart';
import '../../../../models/transaction.dart' as model;
import '../../../../theme/app_theme.dart';
import '../../transactions_screen.dart';
import 'home_transaction_item.dart';

/// Recent transactions list widget
class HomeRecentTransactions extends StatelessWidget {
  final List<model.Transaction> transactions;
  final List<Account> accounts;

  const HomeRecentTransactions({
    super.key,
    required this.transactions,
    required this.accounts,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Activity',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface)),
                TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TransactionsScreen())),
                  child: Text('See All',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text('No transactions yet',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 13))),
            )
          else
            ...List.generate(transactions.length, (i) {
              final t = transactions[i];
              final isIncome = t.type == 'income';
              final color = HomeTransactionItem.color(context, t.category, isIncome);
              final icon = HomeTransactionItem.icon(t.category, isIncome);
              final account =
                  accounts.where((a) => a.id == t.accountId).firstOrNull;
              final timeStr = DateFormat('d MMM, h:mm a').format(t.date);
              final subtitle =
                  account != null ? '${account.name} • $timeStr' : timeStr;

              return Column(
                children: [
                  InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TransactionsScreen())),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                child: Icon(icon,
                                  color: color,
                                  size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.category,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface)),
                                    const SizedBox(height: 3),
                                    Text(subtitle,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5)),
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${isIncome ? '+' : '−'}${fmt.format(t.amount.abs())}',
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
                          if (t.note != null && t.note!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 56),
                              child: Text(
                                t.note!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          if (i < transactions.length - 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 10, left: 56),
                              child: Divider(
                                  height: 1,
                                  color: Theme.of(context).colorScheme.outlineVariant),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
