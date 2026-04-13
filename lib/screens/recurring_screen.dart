import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/recurring_transaction.dart';
import '../models/account.dart';
import '../models/savings_goal.dart';
import '../services/refresh_notifier.dart';
import '../services/recurring_scheduler.dart';
import '../widgets/category_picker.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});
  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<RecurringTransaction> _items = [];
  List<Account> _accounts = [];
  List<SavingsGoal> _goals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    appRefresh.addListener(_load);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final items = await AppDatabase.getRecurring();
    final accounts = await AppDatabase.getAccounts();
    final goals = await AppDatabase.getGoals();
    if (!mounted) return;
    setState(() {
      _items = items;
      _accounts = accounts;
      _goals = goals;
      _loading = false;
    });
  }

  void _showForm([RecurringTransaction? existing]) {
    final amtCtrl = TextEditingController(
        text: existing?.amount.toStringAsFixed(2) ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String type = existing?.type ?? 'expense';
    String frequency = existing?.frequency ?? 'monthly';
    int? accountId = existing?.accountId;
    int? toAccountId = existing?.toAccountId;
    int? goalId = existing?.goalId;
    DateTime nextDue = existing?.nextDueDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Add Recurring' : 'Edit Recurring',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),

                // Type selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'expense', label: Text('Expense')),
                      ButtonSegment(value: 'income', label: Text('Income')),
                      ButtonSegment(value: 'transfer', label: Text('Transfer')),
                      ButtonSegment(value: 'goal', label: Text('Goal')),
                    ],
                    selected: {type},
                    onSelectionChanged: (v) => setLocal(() {
                      type = v.first;
                      // reset dependent fields
                      toAccountId = null;
                      goalId = null;
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                // Category — not needed for transfer/goal
                if (type != 'transfer' && type != 'goal') ...[
                  TextField(
                    controller: catCtrl,
                    readOnly: true,
                    onTap: () async {
                      final picked = await showCategoryPicker(ctx,
                          current: catCtrl.text);
                      if (picked != null) setLocal(() => catCtrl.text = picked);
                    },
                    decoration: const InputDecoration(
                        labelText: 'Category',
                        suffixIcon: Icon(Icons.arrow_drop_down),
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],

                // Transfer: from + to account
                if (type == 'transfer') ...[
                  DropdownButtonFormField<int?>(
                    value: accountId,
                    decoration: const InputDecoration(
                        labelText: 'From Account',
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Select account')),
                      ..._accounts.map((a) => DropdownMenuItem(
                          value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => accountId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: toAccountId,
                    decoration: const InputDecoration(
                        labelText: 'To Account',
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Select account')),
                      ..._accounts
                          .where((a) => a.id != accountId)
                          .map((a) => DropdownMenuItem(
                              value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => toAccountId = v),
                  ),
                  const SizedBox(height: 12),
                ],

                // Goal contribution: goal + source account
                if (type == 'goal') ...[
                  DropdownButtonFormField<int?>(
                    value: goalId,
                    decoration: const InputDecoration(
                        labelText: 'Savings Goal',
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Select goal')),
                      ..._goals.map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(
                              '${g.name} (${(g.progress * 100).toStringAsFixed(0)}%)'))),
                    ],
                    onChanged: (v) => setLocal(() => goalId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: accountId,
                    decoration: const InputDecoration(
                        labelText: 'Deduct from Account (optional)',
                        border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('No account deduction')),
                      ..._accounts.map((a) => DropdownMenuItem(
                          value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => accountId = v),
                  ),
                  const SizedBox(height: 12),
                ],

                // Account for income/expense
                if (type == 'income' || type == 'expense') ...[
                  if (_accounts.isNotEmpty)
                    DropdownButtonFormField<int?>(
                      value: accountId,
                      decoration: const InputDecoration(
                          labelText: 'Account (optional)',
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('No account')),
                        ..._accounts.map((a) => DropdownMenuItem(
                            value: a.id, child: Text(a.name))),
                      ],
                      onChanged: (v) => setLocal(() => accountId = v),
                    ),
                  const SizedBox(height: 12),
                ],

                // Note
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                // Frequency
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(
                      labelText: 'Frequency', border: OutlineInputBorder()),
                  items: RecurringTransaction.frequencies
                      .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f == 'once'
                              ? 'One-time'
                              : f[0].toUpperCase() + f.substring(1))))
                      .toList(),
                  onChanged: (v) => setLocal(() => frequency = v!),
                ),
                const SizedBox(height: 12),

                // Due date
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: nextDue,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setLocal(() => nextDue = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: frequency == 'once' ? 'Date' : 'Next Due Date',
                        border: const OutlineInputBorder()),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM d, yyyy').format(nextDue)),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () async {
                        await AppDatabase.deleteRecurring(existing.id!);
                        notifyDataChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amtCtrl.text);
                      if (amount == null || amount <= 0) return;

                      // Validate by type
                      if (type == 'transfer' &&
                          (accountId == null || toAccountId == null)) return;
                      if (type == 'goal' && goalId == null) return;
                      if ((type == 'income' || type == 'expense') &&
                          catCtrl.text.trim().isEmpty) return;

                      final cat = type == 'transfer'
                          ? 'transfer'
                          : type == 'goal'
                              ? 'savings'
                              : catCtrl.text.trim();

                      final r = RecurringTransaction(
                        id: existing?.id,
                        type: type,
                        amount: amount,
                        category: cat,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                        accountId: accountId,
                        toAccountId: toAccountId,
                        goalId: goalId,
                        frequency: frequency,
                        nextDueDate: nextDue,
                      );
                      if (existing == null) {
                        await AppDatabase.insertRecurring(r);
                        await RecurringScheduler.processDue();
                      } else {
                        await RecurringScheduler.onUpdated(r);
                      }
                      notifyDataChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Process due now',
            onPressed: () async {
              final count = await RecurringScheduler.processDue();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(count > 0
                    ? '$count transaction(s) processed'
                    : 'No transactions due today'),
              ));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text(
                      'No recurring transactions.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final r = _items[i];
                    final fromAccount = _accounts
                        .where((a) => a.id == r.accountId)
                        .firstOrNull;
                    final toAccount = _accounts
                        .where((a) => a.id == r.toAccountId)
                        .firstOrNull;
                    final goal = _goals
                        .where((g) => g.id == r.goalId)
                        .firstOrNull;

                    final isIncome = r.type == 'income';
                    final isTransfer = r.type == 'transfer';
                    final isGoal = r.type == 'goal';

                    Color iconColor = isIncome
                        ? Colors.green
                        : isTransfer
                            ? Colors.blue
                            : isGoal
                                ? Colors.purple
                                : Colors.red;

                    IconData iconData = isIncome
                        ? Icons.arrow_downward
                        : isTransfer
                            ? Icons.swap_horiz
                            : isGoal
                                ? Icons.savings
                                : Icons.arrow_upward;

                    String subtitle = '';
                    if (isTransfer) {
                      subtitle =
                          '${fromAccount?.name ?? '?'} → ${toAccount?.name ?? '?'}';
                    } else if (isGoal) {
                      subtitle = 'Goal: ${goal?.name ?? '?'}';
                      if (fromAccount != null) {
                        subtitle += ' · from ${fromAccount.name}';
                      }
                    } else {
                      subtitle = fromAccount?.name ?? '';
                    }

                    final freqLabel = r.frequency == 'once'
                        ? 'One-time'
                        : r.frequency[0].toUpperCase() +
                            r.frequency.substring(1);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              iconColor.withValues(alpha: 0.15),
                          child: Icon(iconData,
                              color: iconColor, size: 20),
                        ),
                        title: Row(children: [
                          Expanded(
                            child: Text(
                              isTransfer
                                  ? 'Transfer'
                                  : isGoal
                                      ? (goal?.name ?? 'Goal')
                                      : r.category,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (!r.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('done',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ),
                        ]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$freqLabel · Next: ${DateFormat('MMM d, yyyy').format(r.nextDueDate)}'),
                            if (subtitle.isNotEmpty)
                              Text(subtitle,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: Text(
                          fmt.format(r.amount),
                          style: TextStyle(
                              color: iconColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        onTap: () => _showForm(r),
                      ),
                    );
                  },
                ),
    );
  }
}
