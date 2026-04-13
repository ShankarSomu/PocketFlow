import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/transaction.dart' as model;
import '../models/account.dart';
import '../services/refresh_notifier.dart';
import '../widgets/category_picker.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<model.Transaction> _transactions = [];
  List<Account> _accounts = [];
  bool _loading = true;
  String _filter = 'all'; // all | income | expense
  String _search = '';
  final _searchCtrl = TextEditingController();

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
    final txns = await AppDatabase.getTransactions(
      type: _filter == 'all' ? null : _filter,
      keyword: _search.isEmpty ? null : _search,
    );
    final accounts = await AppDatabase.getAccounts();
    if (!mounted) return;
    setState(() {
      _transactions = txns;
      _accounts = accounts;
      _loading = false;
    });
  }

  void _showForm([model.Transaction? existing]) {
    final amtCtrl = TextEditingController(
        text: existing?.amount.toStringAsFixed(2) ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String type = existing?.type ?? 'expense';
    DateTime date = existing?.date ?? DateTime.now();
    int? accountId = existing?.accountId;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(existing == null ? 'Add Transaction' : 'Edit Transaction',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    if (existing != null)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete Transaction?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancel')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          await AppDatabase.deleteTransaction(existing.id!);
                          notifyDataChanged();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setLocal(() => type = v.first),
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
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                // Date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setLocal(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Date', border: OutlineInputBorder()),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM d, yyyy').format(date)),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                if (_accounts.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
                ],
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amtCtrl.text);
                      final cat = catCtrl.text.trim();
                      if (amount == null || amount <= 0 || cat.isEmpty) return;
                      final t = model.Transaction(
                        id: existing?.id,
                        type: type,
                        amount: amount,
                        category: cat,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                        date: date,
                        accountId: accountId,
                      );
                      if (existing == null) {
                        await AppDatabase.insertTransaction(t);
                      } else {
                        await AppDatabase.updateTransaction(t);
                      }
                      notifyDataChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(existing == null ? 'Add' : 'Save'),
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
    // Group by date
    final grouped = <String, List<model.Transaction>>{};
    for (final t in _transactions) {
      final key = DateFormat('MMM d, yyyy').format(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        // Search + filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                            _load();
                          })
                      : null,
                ),
                onChanged: (v) {
                  setState(() => _search = v);
                  _load();
                },
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'income', label: Text('In')),
                ButtonSegment(value: 'expense', label: Text('Out')),
              ],
              selected: {_filter},
              onSelectionChanged: (v) {
                setState(() { _filter = v.first; _loading = true; });
                _load();
              },
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                  ? const Center(
                      child: Text('No transactions found.',
                          style: TextStyle(color: Colors.grey)))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: grouped.entries.map((entry) {
                        final dayTotal = entry.value.fold(0.0, (s, t) =>
                            t.type == 'income' ? s + t.amount : s - t.amount);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.grey)),
                                  Text(
                                    fmt.format(dayTotal),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: dayTotal >= 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            ...entry.value.map((t) {
                              final isIncome = t.type == 'income';
                              final account = _accounts
                                  .where((a) => a.id == t.accountId)
                                  .firstOrNull;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: (isIncome
                                            ? Colors.green
                                            : Colors.red)
                                        .withValues(alpha: 0.12),
                                    child: Icon(
                                      isIncome
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      size: 16,
                                      color: isIncome
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  title: Text(t.category,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14)),
                                  subtitle: Text(
                                    [
                                      if (t.note != null) t.note!,
                                      if (account != null) account.name,
                                    ].join(' · '),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Text(
                                    fmt.format(t.amount),
                                    style: TextStyle(
                                        color: isIncome
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  onTap: () => _showForm(t),
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
        ),
      ]),
    );
  }
}
