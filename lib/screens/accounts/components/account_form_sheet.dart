import 'package:flutter/material.dart';

import '../../../core/haptic_feedback.dart';
import '../../../models/account.dart';

typedef SaveAccountCallback = Future<void> Function(Account account);
typedef DeleteAccountCallback = Future<void> Function(Account account);

Future<void> showAccountFormSheet(
  BuildContext context, {
  Account? existing,
  required Map<int, double> balances,
  required SaveAccountCallback onSave,
  required DeleteAccountCallback onDelete,
}) async {
  String selectedType = existing?.type ?? 'checking';
  int? dueDateDay = existing?.dueDateDay;
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final computedBalance = existing != null ? (balances[existing.id] ?? existing.balance) : 0.0;
  final balanceValue = existing != null
      ? (existing.isLiability ? computedBalance.abs() : computedBalance)
      : 0.0;
  final balCtrl = TextEditingController(
    text: existing != null ? balanceValue.toStringAsFixed(2) : '',
  );
  final last4Ctrl = TextEditingController(text: existing?.last4 ?? '');
  final limitCtrl = TextEditingController(
    text: existing?.creditLimit != null ? existing!.creditLimit!.toStringAsFixed(2) : '',
  );
  final institutionCtrl = TextEditingController(text: existing?.institutionName ?? '');
  final identifierCtrl = TextEditingController(text: existing?.accountIdentifier ?? '');
  final keywordsCtrl = TextEditingController(text: existing?.smsKeywords?.join(', ') ?? '');
  final aliasCtrl = TextEditingController(text: existing?.accountAlias ?? '');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: StatefulBuilder(
        builder: (ctx, setLocal) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Add Account' : 'Edit Account',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'checking', child: Text('Salary / Checking')),
                  DropdownMenuItem(value: 'savings', child: Text('Savings')),
                  DropdownMenuItem(value: 'credit_card', child: Text('Credit Card')),
                  DropdownMenuItem(value: 'loan', child: Text('Loan')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'investment', child: Text('Investment')),
                  DropdownMenuItem(value: 'unidentified', child: Text('Unidentified (Auto-created)')),
                ],
                onChanged: (v) => setLocal(() => selectedType = v ?? 'checking'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: (selectedType == 'credit_card' || selectedType == 'loan')
                      ? 'Current Balance (amount owed)'
                      : 'Opening Balance',
                  prefixText: '\$',
                  border: const OutlineInputBorder(),
                  helperText: (selectedType == 'credit_card' || selectedType == 'loan')
                      ? 'Amount you currently owe on this ${selectedType == 'loan' ? 'loan' : 'card'}'
                      : 'Your current balance in this account',
                ),
              ),
              if (selectedType == 'credit_card' || selectedType == 'loan') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: limitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: selectedType == 'loan'
                        ? 'Original Loan Amount (optional)'
                        : 'Credit Limit (optional)',
                    prefixText: '\$',
                    border: const OutlineInputBorder(),
                    helperText: selectedType == 'loan'
                        ? 'Total amount borrowed initially'
                        : 'Maximum credit available',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: dueDateDay,
                  decoration: InputDecoration(
                    labelText: selectedType == 'loan' ? 'Payment Due Date' : 'Credit Card Due Date',
                    border: const OutlineInputBorder(),
                    helperText: 'Day of month when payment is due',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No due date')),
                    ...List.generate(
                      28,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}${_daySuffix(i + 1)} of each month'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => dueDateDay = v),
                ),
              ],
              if (selectedType == 'credit_card') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: last4Ctrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Last 4 Digits of Card (optional)',
                    hintText: '1234',
                    border: OutlineInputBorder(),
                    helperText: 'Printed on your physical card',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'SMS Auto-Matching (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Help automatically link SMS transactions to this account',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: institutionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Institution Name',
                  hintText: 'e.g., Chase, Bank of America, Citi',
                  border: OutlineInputBorder(),
                  helperText: 'Your bank or financial institution',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: identifierCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Number from SMS',
                  hintText: 'e.g., 3530, ****1234, XX5678',
                  border: OutlineInputBorder(),
                  helperText: 'Account number as it appears in SMS alerts',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keywordsCtrl,
                decoration: const InputDecoration(
                  labelText: 'SMS Sender IDs (optional)',
                  hintText: 'e.g., CHASE, BOFA, CITI',
                  border: OutlineInputBorder(),
                  helperText: 'Comma-separated sender names from SMS',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: aliasCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display Alias (optional)',
                  hintText: 'e.g., My Main Card, Savings Fund',
                  border: OutlineInputBorder(),
                  helperText: 'Friendly nickname for this account',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Account?'),
                            content: const Text(
                              'Transactions linked to this account will be unlinked but not deleted.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || existing == null) return;
                        await HapticFeedbackHelper.heavyImpact();
                        await onDelete(existing);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final bal = double.tryParse(balCtrl.text) ?? 0;
                      if (name.isEmpty) return;

                      final keywordsText = keywordsCtrl.text.trim();
                      final keywords = keywordsText.isNotEmpty
                          ? keywordsText
                              .split(',')
                              .map((k) => k.trim())
                              .where((k) => k.isNotEmpty)
                              .toList()
                          : null;

                      final account = Account(
                        id: existing?.id,
                        name: name,
                        type: selectedType,
                        balance: bal,
                        last4: last4Ctrl.text.trim().isEmpty ? null : last4Ctrl.text.trim(),
                        dueDateDay: (selectedType == 'credit_card' || selectedType == 'loan')
                            ? dueDateDay
                            : null,
                        creditLimit: (selectedType == 'credit_card' || selectedType == 'loan')
                            ? double.tryParse(limitCtrl.text)
                            : null,
                        institutionName: institutionCtrl.text.trim().isEmpty
                            ? null
                            : institutionCtrl.text.trim(),
                        accountIdentifier: identifierCtrl.text.trim().isEmpty
                            ? null
                            : identifierCtrl.text.trim(),
                        smsKeywords: keywords,
                        accountAlias: aliasCtrl.text.trim().isEmpty ? null : aliasCtrl.text.trim(),
                      );
                      await onSave(account);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _daySuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  return switch (day % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
}
