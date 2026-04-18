import '../../services/time_filter.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../db/database.dart';
import '../../models/transaction.dart' as model;
import '../../models/account.dart';
import '../../services/refresh_notifier.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/empty_states.dart';
import '../../widgets/error_state_widget.dart';
import '../shared/shared.dart';
import 'components/transactions_components.dart';

class TransactionsScreen extends StatefulWidget {
  final String? initialFilterType;
  final int? initialAccountId;
  const TransactionsScreen({super.key, this.initialFilterType, this.initialAccountId});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _loading = true;
  String? _error;
  bool _searchVisible = false;
  List<model.Transaction> _transactions = [];
  List<Account> _accounts = [];
  Map<int, double> _accountBalances = {};
  int _carouselIdx = 0; // 0 = All, 1..N = individual account
  String _searchQuery = '';
  String? _filterType;
  int? _filterAccountId;

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialFilterType;
    _filterAccountId = widget.initialAccountId;
    _load();
    appRefresh.addListener(_load);
    appTimeFilter.addListener(_load);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    appTimeFilter.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final filter = appTimeFilter.current;
      final transactions = await AppDatabase.getTransactions(from: filter.from, to: filter.to);
      final accounts = await AppDatabase.getAccounts();
      final balances = <int, double>{};
      for (final a in accounts) {
        balances[a.id!] = await AppDatabase.accountBalance(a.id!, a);
      }
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _accounts = accounts;
        _accountBalances = balances;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load transactions: $e';
        _loading = false;
      });
    }
  }

  List<model.Transaction> get _filteredTransactions {
    var filtered = _transactions;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return t.category.toLowerCase().contains(query) ||
            (t.note?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    if (_filterType != null) {
      filtered = filtered.where((t) => t.type == _filterType).toList();
    }
    if (_filterAccountId != null) {
      filtered = filtered.where((t) => t.accountId == _filterAccountId).toList();
    }
    return filtered;
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Text('Type', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text('All'),
                    selected: _filterType == null,
                    onSelected: (v) => setLocal(() => _filterType = null),
                  ),
                  FilterChip(
                    label: Text('Income'),
                    selected: _filterType == 'income',
                    onSelected: (v) => setLocal(() => _filterType = v ? 'income' : null),
                  ),
                  FilterChip(
                    label: Text('Expense'),
                    selected: _filterType == 'expense',
                    onSelected: (v) => setLocal(() => _filterType = v ? 'expense' : null),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Account', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: _filterAccountId,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All accounts')),
                  ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (v) => setLocal(() => _filterAccountId = v),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setLocal(() {
                          _filterType = null;
                          _filterAccountId = null;
                        });
                      },
                      child: Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      child: Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportTransactions() async {
    final filtered = _filteredTransactions;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No transactions to export')));
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Date,Type,Category,Amount,Note,Account');
    for (final t in filtered) {
      final account = _accounts.where((a) => a.id == t.accountId).firstOrNull;
      buffer.writeln(
        '${DateFormat('yyyy-MM-dd').format(t.date)},'
        '${t.type},'
        '${t.category},'
        '${t.amount},'
        '"${t.note ?? ''}",'
        '${account?.name ?? ''}'
      );
    }

    try {
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final fileName = 'transactions_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buffer.toString());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${file.path}'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Map<String, List<model.Transaction>> _groupByDate(List<model.Transaction> txns) {
    final groups = <String, List<model.Transaction>>{};
    for (final t in txns) {
      final key = DateFormat('d MMMM').format(t.date);
      groups.putIfAbsent(key, () => []).add(t);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final filtered = _filteredTransactions;
    final groups = _groupByDate(filtered);
    final groupKeys = groups.keys.toList();
    final totalIncome = filtered.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    final totalExpense = filtered.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
    final selectedAccount = _filterAccountId == null ? null : _accounts.where((a) => a.id == _filterAccountId).firstOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            _loading
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                : _error != null
                    ? ErrorStateWidget(
                        message: _error!,
                        onRetry: _load,
                      )
                    : Column(
                children: [
                  const ScreenHeader(
                    'Transactions',
                    icon: Icons.receipt_long_rounded,
                    subtitle: 'All income and expenses',
                  ),
                  // -- Account Carousel --
                  if (_accounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TransactionAccountCarousel(
                        accounts: _accounts,
                        balances: _accountBalances,
                        carouselIdx: _carouselIdx,
                        onIndexChanged: (i) {
                          setState(() {
                            _carouselIdx = i;
                            _filterAccountId = i == 0 ? null : _accounts[i - 1].id;
                          });
                        },
                        fmt: fmt,
                      ),
                    ),
                  // -- Active filter chips (type only) --
                  if (_filterType != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(_filterType == 'income' ? '? Income' : '? Expense',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            onDeleted: () => setState(() => _filterType = null),
                            deleteIcon: Icon(Icons.close, size: 14),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ],
                      ),
                    ),
                  // -- Grouped Transaction List --
                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyStates.transactions(context, onAdd: _showAddTransactionForm)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                              itemCount: groupKeys.length,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                              cacheExtent: 500,
                              itemBuilder: (context, i) {
                                final dateLabel = groupKeys[i];
                                final txns = groups[dateLabel]!;
                                return TransactionDateSection(
                                  dateLabel: dateLabel,
                                  transactions: txns,
                                  accounts: _accounts,
                                  fmt: fmt,
                                  onTap: _showEditTransaction,
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            const Positioned(
              bottom: 16,
              left: 16,
              child: CalendarFab(),
            ),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              right: 16,
              child: SpeedDialFab(
                actions: [
                  SpeedDialAction(
                    icon: Icons.add,
                    label: 'Add Transaction',
                    onPressed: _showAddTransactionForm,
                  ),
                  SpeedDialAction(
                    icon: Icons.filter_list_rounded,
                    label: 'Filter',
                    onPressed: _showFilters,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTransactionForm() {
    String type = 'expense';
    int? accountId = _accounts.isNotEmpty ? _accounts.first.id : null;
    DateTime selectedDate = DateTime.now();
    final amtCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

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
                Text('Add Transaction',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'expense',
                          label: Text('Expense'),
                          icon: Icon(Icons.arrow_upward, size: 14)),
                      ButtonSegment(
                          value: 'income',
                          label: Text('Income'),
                          icon: Icon(Icons.arrow_downward, size: 14)),
                    ],
                    selected: {type},
                    onSelectionChanged: (v) =>
                        setLocal(() => type = v.first),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: catCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  onTap: () async {
                    final picked = await showCategoryPicker(context,
                        current: catCtrl.text);
                    if (picked != null)
                      setLocal(() => catCtrl.text = picked);
                  },
                ),
                const SizedBox(height: 12),
                if (_accounts.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    value: accountId,
                    decoration: const InputDecoration(
                      labelText: 'Account',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('No account')),
                      ..._accounts.map((a) => DropdownMenuItem(
                          value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => accountId = v),
                  ),
                if (_accounts.isNotEmpty) const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate:
                          DateTime(DateTime.now().year + 2, 12, 31),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Theme.of(context).colorScheme.primary,
                            onPrimary: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null)
                      setLocal(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, yyyy').format(selectedDate),
                          style: TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
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
                      child: Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final amount = double.tryParse(amtCtrl.text);
                        final category = catCtrl.text.trim();
                        if (amount == null ||
                            amount <= 0 ||
                            category.isEmpty) return;
                        await AppDatabase.insertTransaction(
                          model.Transaction(
                            type: type,
                            amount: amount,
                            category: category,
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                            date: selectedDate,
                            accountId: accountId,
                          ),
                        );
                        notifyDataChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text('Add'),
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

  void _showEditTransaction(model.Transaction transaction) {
    final amtCtrl = TextEditingController(text: transaction.amount.toStringAsFixed(2));
    final catCtrl = TextEditingController(text: transaction.category);
    final noteCtrl = TextEditingController(text: transaction.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit ${transaction.type[0].toUpperCase()}${transaction.type.substring(1)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    await AppDatabase.deleteTransaction(transaction.id!);
                    notifyDataChanged();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: catCtrl,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
            ),
            if (transaction.smsSource != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sms_outlined, 
                          size: 16, 
                          color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'SMS Source',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      transaction.smsSource!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amtCtrl.text);
                  final category = catCtrl.text.trim();
                  if (amount == null || amount <= 0 || category.isEmpty) return;
                  await AppDatabase.updateTransaction(model.Transaction(
                    id: transaction.id,
                    type: transaction.type,
                    amount: amount,
                    category: category,
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    date: transaction.date,
                    accountId: transaction.accountId,
                  ));
                  notifyDataChanged();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text('Save'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
