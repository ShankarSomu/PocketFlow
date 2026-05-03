import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../db/database.dart';
import '../../../models/recurring_transaction.dart';
import '../../../models/transaction.dart' as model;

/// Bottom sheet showing all past transactions linked to a recurring entry.
class RecurringHistorySheet extends StatefulWidget {
  const RecurringHistorySheet({required this.item, super.key});
  final RecurringTransaction item;

  @override
  State<RecurringHistorySheet> createState() => _RecurringHistorySheetState();
}

class _RecurringHistorySheetState extends State<RecurringHistorySheet> {
  List<model.Transaction> _txns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.db();
    final rows = await db.query(
      'transactions',
      where: 'recurring_id = ? AND deleted_at IS NULL',
      whereArgs: [widget.item.id],
      orderBy: 'date DESC',
    );
    if (!mounted) return;
    setState(() {
      _txns = rows.map(model.Transaction.fromMap).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final item = widget.item;
    final isIncome = item.type == 'income';

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.frequency[0].toUpperCase()}${item.frequency.substring(1)}  •  ${fmt.format(item.amount)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (item.startDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Started ${DateFormat('MMM d, yyyy').format(item.startDate!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_txns.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_txns.length} payments',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fmt.format(_txns.fold(0.0, (s, t) => s + t.amount)),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isIncome
                              ? Colors.green.shade600
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Transaction list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _txns.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No transactions yet',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _txns.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 72,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        itemBuilder: (_, i) {
                          final txn = _txns[i];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (isIncome ? Colors.green : Theme.of(context).colorScheme.primary)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                size: 18,
                                color: isIncome ? Colors.green.shade600 : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              DateFormat('MMM d, yyyy').format(txn.date),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            subtitle: txn.note != null && txn.note!.isNotEmpty
                                ? Text(
                                    txn.note!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                            trailing: Text(
                              '${isIncome ? '+' : '-'}${fmt.format(txn.amount)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isIncome ? Colors.green.shade600 : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
