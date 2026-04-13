import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/account.dart';
import '../services/refresh_notifier.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Account> _accounts = [];
  Map<int, double> _balances = {};
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
    final accounts = await AppDatabase.getAccounts();
    final balances = <int, double>{};
    for (final a in accounts) {
      balances[a.id!] = await AppDatabase.accountBalance(a.id!, a);
    }
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _balances = balances;
      _loading = false;
    });
  }

  void _showForm([Account? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final balCtrl = TextEditingController(
        text: existing?.balance.toStringAsFixed(2) ?? '0');
    final last4Ctrl = TextEditingController(text: existing?.last4);
    final limitCtrl = TextEditingController(
        text: existing?.creditLimit?.toStringAsFixed(2) ?? '');
    String selectedType = existing?.type ?? 'checking';
    int? dueDateDay = existing?.dueDateDay;

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
                Text(existing == null ? 'Add Account' : 'Edit Account',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Account Name',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                      labelText: 'Type', border: OutlineInputBorder()),
                  items: Account.types
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Row(children: [
                              Icon(_typeIcon(t), size: 18),
                              const SizedBox(width: 8),
                              Text(t[0].toUpperCase() + t.substring(1)),
                            ]),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: selectedType == 'credit'
                        ? 'Current Balance Owed'
                        : 'Opening Balance',
                    border: const OutlineInputBorder(),
                    prefixText: '\$',
                    helperText: selectedType == 'credit'
                        ? 'Amount you currently owe on this card'
                        : 'Starting balance for this account',
                  ),
                ),
                // Credit card specific fields
                if (selectedType == 'credit') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: last4Ctrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Last 4 digits (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Credit Limit (optional)',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Due date day picker
                  DropdownButtonFormField<int?>(
                    value: dueDateDay,
                    decoration: const InputDecoration(
                      labelText: 'Payment Due Date (day of month)',
                      border: OutlineInputBorder(),
                      helperText: 'e.g. 15 = due on 15th of each month',
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('No due date')),
                      ...List.generate(
                          28,
                          (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1}${_daySuffix(i + 1)} of each month'))),
                    ],
                    onChanged: (v) => setLocal(() => dueDateDay = v),
                  ),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Account?'),
                            content: const Text(
                                'Transactions linked to this account will be unlinked but not deleted.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await AppDatabase.deleteAccount(existing.id!);
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
                      final name = nameCtrl.text.trim();
                      final bal = double.tryParse(balCtrl.text) ?? 0;
                      if (name.isEmpty) return;
                      final account = Account(
                        id: existing?.id,
                        name: name,
                        type: selectedType,
                        balance: bal,
                        last4: last4Ctrl.text.trim().isEmpty
                            ? null
                            : last4Ctrl.text.trim(),
                        dueDateDay: selectedType == 'credit' ? dueDateDay : null,
                        creditLimit: selectedType == 'credit'
                            ? double.tryParse(limitCtrl.text)
                            : null,
                      );
                      if (existing == null) {
                        await AppDatabase.insertAccount(account);
                      } else {
                        await AppDatabase.updateAccount(account);
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

  void _showTransferDialog() {
    if (_accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 accounts to transfer')),
      );
      return;
    }
    int? fromId = _accounts.first.id;
    int? toId = _accounts.length > 1 ? _accounts[1].id : null;
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool useOutstanding = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            final toAccount =
                _accounts.where((a) => a.id == toId).firstOrNull;
            final isCreditTarget = toAccount?.type == 'credit';
            final outstanding = toId != null ? (_balances[toId] ?? 0) : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transfer Between Accounts',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                const Text(
                  'Use this to pay a credit card or move money between accounts.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: fromId,
                  decoration: const InputDecoration(
                      labelText: 'From Account',
                      border: OutlineInputBorder()),
                  items: _accounts
                      .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                              '${a.name} (${_fmt.format(_balances[a.id] ?? 0)})')))
                      .toList(),
                  onChanged: (v) => setLocal(() => fromId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: toId,
                  decoration: const InputDecoration(
                      labelText: 'To Account',
                      border: OutlineInputBorder()),
                  items: _accounts
                      .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Row(children: [
                            Expanded(child: Text(a.name)),
                            if (a.type == 'credit')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                    'owes ${_fmt.format(_balances[a.id] ?? 0)}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.red)),
                              ),
                          ])))
                      .toList(),
                  onChanged: (v) => setLocal(() {
                    toId = v;
                    useOutstanding = false;
                    amtCtrl.clear();
                  }),
                ),
                const SizedBox(height: 12),
                // Outstanding balance option for credit cards
                if (isCreditTarget && outstanding > 0) ...[
                  CheckboxListTile(
                    value: useOutstanding,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        'Pay full outstanding: ${_fmt.format(outstanding)}',
                        style: const TextStyle(fontSize: 13)),
                    subtitle: const Text(
                        'Amount will update automatically each time',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
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
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      if (fromId == null ||
                          toId == null ||
                          fromId == toId) return;
                      final amount = useOutstanding
                          ? (_balances[toId] ?? 0)
                          : double.tryParse(amtCtrl.text);
                      if (amount == null || amount <= 0) return;
                      await AppDatabase.transfer(
                        fromId: fromId!,
                        toId: toId!,
                        amount: amount,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      );
                      notifyDataChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Transfer'),
                  ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

  final _fmt = NumberFormat.currency(symbol: '\$');

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    double totalAssets = 0, totalDebt = 0;
    for (final a in _accounts) {
      final bal = _balances[a.id] ?? 0;
      if (a.type == 'credit') {
        totalDebt += bal;
      } else {
        totalAssets += bal;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          if (_accounts.length >= 2)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Transfer',
              onPressed: _showTransferDialog,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? const Center(
                  child: Text('No accounts yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _NetItem('Assets', totalAssets, Colors.green),
                            _NetItem('Debt', totalDebt, Colors.red),
                            _NetItem(
                                'Net Worth',
                                totalAssets - totalDebt,
                                totalAssets >= totalDebt
                                    ? Colors.blue
                                    : Colors.orange),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildGrouped(fmt),
                  ],
                ),
    );
  }

  List<Widget> _buildGrouped(NumberFormat fmt) {
    final groups = <String, List<Account>>{};
    for (final a in _accounts) {
      groups.putIfAbsent(a.type, () => []).add(a);
    }
    final widgets = <Widget>[];
    for (final type in Account.types) {
      if (!groups.containsKey(type)) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(type[0].toUpperCase() + type.substring(1),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey)),
      ));
      for (final a in groups[type]!) {
        final bal = _balances[a.id] ?? 0;
        final isCredit = a.type == 'credit';
        final daysUntil = a.daysUntilDue;

        widgets.add(Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _typeColor(a.type).withValues(alpha: 0.15),
              child: Icon(_typeIcon(a.type),
                  color: _typeColor(a.type), size: 20),
            ),
            title: Text(a.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a.last4 != null)
                  Text('•••• ${a.last4}',
                      style: const TextStyle(fontSize: 12)),
                if (isCredit && daysUntil != null)
                  Row(children: [
                    Icon(
                      daysUntil <= 3
                          ? Icons.warning_amber
                          : Icons.calendar_today,
                      size: 11,
                      color: daysUntil <= 3 ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      daysUntil == 0
                          ? 'Due today!'
                          : daysUntil < 0
                              ? 'Overdue!'
                              : 'Due in $daysUntil days',
                      style: TextStyle(
                          fontSize: 11,
                          color: daysUntil <= 3 ? Colors.red : Colors.grey),
                    ),
                    if (a.creditLimit != null) ...[
                      const Text(' · ',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                          '${((bal / a.creditLimit!) * 100).toStringAsFixed(0)}% used',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ]),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmt.format(bal),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCredit
                            ? (bal > 0 ? Colors.red : Colors.green)
                            : Colors.green,
                        fontSize: 15)),
                Text(isCredit ? 'outstanding' : 'available',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
              ],
            ),
            onTap: () => _showForm(a),
          ),
        ));
      }
    }
    return widgets;
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

  IconData _typeIcon(String type) => switch (type) {
        'checking' => Icons.account_balance,
        'savings' => Icons.savings,
        'credit' => Icons.credit_card,
        'cash' => Icons.payments,
        _ => Icons.account_balance_wallet,
      };

  Color _typeColor(String type) => switch (type) {
        'checking' => Colors.blue,
        'savings' => Colors.green,
        'credit' => Colors.red,
        'cash' => Colors.orange,
        _ => Colors.purple,
      };
}

class _NetItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _NetItem(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 4),
      Text(fmt.format(amount),
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 14)),
    ]);
  }
}
