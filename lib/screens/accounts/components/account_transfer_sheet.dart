import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/account.dart';

typedef TransferCallback = Future<void> Function({
  required int fromId,
  required int toId,
  required double amount,
  String? note,
});

Future<void> showAccountTransferSheet(
  BuildContext context, {
  required List<Account> accounts,
  required Map<int, double> balances,
  required NumberFormat fmt,
  required TransferCallback onTransfer,
}) async {
  if (accounts.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add at least 2 accounts to transfer')),
    );
    return;
  }

  int? fromId = accounts.first.id;
  int? toId = accounts.length > 1 ? accounts[1].id : null;
  final amtCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  bool useOutstanding = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          Account? toAccount;
          for (final account in accounts) {
            if (account.id == toId) {
              toAccount = account;
              break;
            }
          }
          final isCreditTarget = toAccount?.isLiability ?? false;
          final outstanding = toId != null ? (balances[toId] ?? 0) : 0.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transfer Between Accounts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Use this to pay a credit card or move money between accounts.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: fromId,
                decoration: const InputDecoration(
                  labelText: 'From Account',
                  border: OutlineInputBorder(),
                ),
                items: accounts
                    .map(
                      (a) => DropdownMenuItem<int?>(
                        value: a.id,
                        child: Text('${a.name} (${fmt.format(balances[a.id] ?? 0)})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => fromId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: toId,
                decoration: const InputDecoration(
                  labelText: 'To Account',
                  border: OutlineInputBorder(),
                ),
                items: accounts
                    .map<DropdownMenuItem<int?>>(
                      (a) => DropdownMenuItem<int?>(
                        value: a.id,
                        child: Row(
                          children: [
                            Expanded(child: Text(a.name)),
                            if (a.isLiability)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'owes ${fmt.format(balances[a.id] ?? 0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() {
                  toId = v;
                  useOutstanding = false;
                  amtCtrl.clear();
                }),
              ),
              const SizedBox(height: 12),
              if (isCreditTarget && outstanding > 0) ...[
                CheckboxListTile(
                  value: useOutstanding,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Pay full outstanding: ${fmt.format(outstanding)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    'Amount will update automatically each time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  onChanged: (v) => setLocal(() {
                    useOutstanding = v ?? false;
                    if (useOutstanding) {
                      amtCtrl.text = outstanding.toStringAsFixed(2);
                    } else {
                      amtCtrl.clear();
                    }
                  }),
                ),
              ],
              if (!useOutstanding)
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (fromId == null || toId == null || fromId == toId) return;
                      final amount = useOutstanding ? (balances[toId] ?? 0) : double.tryParse(amtCtrl.text);
                      if (amount == null || amount <= 0) return;
                      await onTransfer(
                        fromId: fromId!,
                        toId: toId!,
                        amount: amount,
                        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Transfer'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}
