import '../../services/time_filter.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../db/database.dart';
import '../../models/transaction.dart' as model;
import '../../models/account.dart';
import '../../services/refresh_notifier.dart';
import '../../services/theme_service.dart';
import '../../widgets/category_picker.dart';
import 'shared.dart';

class TransactionsScreen extends StatefulWidget {
  final String? initialFilterType;
  final int? initialAccountId;
  const TransactionsScreen({super.key, this.initialFilterType, this.initialAccountId});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _loading = true;
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
                ? Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : Column(
                children: [
                  const ScreenHeader('Transactions'),
                  // -- Account Carousel --
                  if (_accounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _TxAccountCarousel(
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
                            backgroundColor: const Color(0xFFDBEAFE),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ],
                      ),
                    ),
                  // -- Grouped Transaction List --
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 56, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                                const SizedBox(height: 12),
                                Text('No transactions found',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 15)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                              itemCount: groupKeys.length,
                              itemBuilder: (context, i) {
                                final dateLabel = groupKeys[i];
                                final txns = groups[dateLabel]!;
                                return _DateSection(
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
              bottom: 16,
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
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF2563EB),
                            onPrimary: Colors.white,
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
                      border: Border.all(color: Colors.grey.shade400),
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
                  icon: Icon(Icons.delete, color: Colors.red),
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

// ------------------------------------------------------------------------------
// Reusable Components
// ------------------------------------------------------------------------------

class _AccountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool light;
  const _AccountChip({required this.label, required this.selected, required this.onTap, this.light = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (light ? Colors.white : Theme.of(context).colorScheme.primary)
              : (light ? Colors.white.withOpacity(0.18) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: light ? null : ThemeService.instance.primaryShadow,
          border: light ? null : (selected ? null : Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? (light ? Theme.of(context).colorScheme.primary : Colors.white)
                : (light ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
      ),
    );
  }
}

/// CardSummary � gradient card showing net balance and income/expense split.
class _CardSummary extends StatelessWidget {
  final Account? account;
  final double totalIncome;
  final double totalExpense;
  final int transactionCount;
  final NumberFormat fmt;

  const _CardSummary({
    required this.account,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final net = totalIncome - totalExpense;
    final masked = account != null && account!.last4 != null
        ? '**** ${account!.last4}'
        : '**** ----';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ThemeService.instance.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ThemeService.instance.primaryShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.credit_card_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account?.name ?? 'All Accounts',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(masked, style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$transactionCount txns',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
              Text('Net Balance', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(fmt.format(net),
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryPill(
                  label: 'Income',
                  amount: fmt.format(totalIncome),
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF34D399),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryPill(
                  label: 'Expenses',
                  amount: fmt.format(totalExpense),
                  icon: Icons.arrow_upward_rounded,
                  color: const Color(0xFFF87171),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;
  const _SummaryPill({required this.label, required this.amount, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text(amount,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Account Carousel for Transactions screen ─────────────────────────────────

class _TxAccountCarousel extends StatelessWidget {
  final List<Account> accounts;
  final Map<int, double> balances;
  final int carouselIdx; // 0 = All, 1..N = individual
  final ValueChanged<int> onIndexChanged;
  final NumberFormat fmt;

  const _TxAccountCarousel({
    required this.accounts,
    required this.balances,
    required this.carouselIdx,
    required this.onIndexChanged,
    required this.fmt,
  });

  static List<Color> _gradient(String type) => switch (type) {
        'checking' || 'debit' => [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
        'savings' => [const Color(0xFF059669), const Color(0xFF047857)],
        'credit' => [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
        'cash' => [const Color(0xFFD97706), const Color(0xFFB45309)],
        'investment' => [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
        _ => [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      };

  static IconData _icon(String type) => switch (type) {
        'checking' || 'debit' => Icons.account_balance_rounded,
        'savings' => Icons.savings_rounded,
        'credit' => Icons.credit_card_rounded,
        'cash' => Icons.payments_rounded,
        'investment' => Icons.trending_up_rounded,
        _ => Icons.account_balance_wallet_rounded,
      };

  int get _total => accounts.length + 1; // +1 for "All" card

  void _prev() => onIndexChanged((carouselIdx - 1 + _total) % _total);
  void _next() => onIndexChanged((carouselIdx + 1) % _total);

  @override
  Widget build(BuildContext context) {
    // Compute "All" total balance
    double totalBalance = 0;
    for (final a in accounts) {
      final bal = balances[a.id] ?? 0;
      totalBalance += a.type == 'credit' ? -bal : bal;
    }

    Widget cardContent;
    List<Color> gradColors;

    if (carouselIdx == 0) {
      // All accounts card
      gradColors = [const Color(0xFF1E293B), const Color(0xFF0F172A)];
      cardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('All Accounts',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${accounts.length} accounts',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Net Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(fmt.format(totalBalance),
              style: TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: -0.5)),
        ],
      );
    } else {
      final account = accounts[carouselIdx - 1];
      final balance = balances[account.id] ?? 0;
      gradColors = _gradient(account.type);
      cardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(account.type), color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name,
                        style: TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      account.type[0].toUpperCase() + account.type.substring(1) +
                          (account.last4 != null ? '  ····${account.last4}' : ''),
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            account.type == 'credit' ? 'Outstanding' : 'Balance',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(fmt.format(balance),
              style: TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: -0.5)),
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.fromLTRB(44, 16, 44, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: gradColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: ThemeService.instance.primaryShadow,
          ),
          child: cardContent,
        ),
        // Page dots
        Positioned(
          bottom: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_total, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == carouselIdx ? 14 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: i == carouselIdx ? Colors.white : Colors.white38,
                borderRadius: BorderRadius.circular(4),
              ),
            )),
          ),
        ),
        // Left arrow (circular)
        Positioned(
          left: 0,
          child: _TxArrow(icon: Icons.chevron_left_rounded, onTap: _prev),
        ),
        // Right arrow (circular)
        Positioned(
          right: 0,
          child: _TxArrow(icon: Icons.chevron_right_rounded, onTap: _next),
        ),
      ],
    );
  }
}

class _TxArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TxArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
      ),
    );
  }
}

/// DateSection — date group header + list of TransactionItems in a white card.
class _DateSection extends StatelessWidget {
  final String dateLabel;
  final List<model.Transaction> transactions;
  final List<Account> accounts;
  final NumberFormat fmt;
  final void Function(model.Transaction) onTap;

  const _DateSection({
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: transactions.asMap().entries.map((e) {
              final isLast = e.key == transactions.length - 1;
              return _TransactionItem(
                transaction: e.value,
                account: accounts.where((a) => a.id == e.value.accountId).firstOrNull,
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

class _TransactionItem extends StatelessWidget {
  final model.Transaction transaction;
  final Account? account;
  final NumberFormat fmt;
  final bool showDivider;
  final VoidCallback onTap;

  const _TransactionItem({
    required this.transaction,
    required this.account,
    required this.fmt,
    required this.showDivider,
    required this.onTap,
  });

  static Color _colorForCategory(String category) {
    if (category.contains('food') || category.contains('lunch') || category.contains('dinner') || category.contains('restaurant') || category.contains('grocery') || category.contains('groceries')) return const Color(0xFFFF6B35);
    if (category.contains('transport') || category.contains('uber') || category.contains('gas') || category.contains('car') || category.contains('fuel')) return const Color(0xFF3B82F6);
    if (category.contains('shopping') || category.contains('amazon') || category.contains('retail') || category.contains('clothes')) return const Color(0xFF8B5CF6);
    if (category.contains('netflix') || category.contains('spotify') || category.contains('subscription') || category.contains('streaming')) return const Color(0xFFEF4444);
    if (category.contains('health') || category.contains('medical') || category.contains('doctor') || category.contains('pharmacy')) return const Color(0xFF06B6D4);
    if (category.contains('home') || category.contains('rent') || category.contains('mortgage') || category.contains('electric') || category.contains('utility')) return const Color(0xFFF59E0B);
    if (category.contains('gym') || category.contains('fitness') || category.contains('sport')) return const Color(0xFF10B981);
    if (category.contains('travel') || category.contains('flight') || category.contains('hotel') || category.contains('vacation')) return const Color(0xFF0EA5E9);
    if (category.contains('coffee') || category.contains('cafe') || category.contains('tea')) return const Color(0xFFB45309);
    if (category.contains('education') || category.contains('school') || category.contains('book') || category.contains('tuition')) return const Color(0xFF7C3AED);
    return const Color(0xFF6366F1);
  }

  static IconData _iconForCategory(String category) {
    if (category.contains('food') || category.contains('lunch') || category.contains('dinner') || category.contains('restaurant') || category.contains('grocery') || category.contains('groceries')) return Icons.restaurant_rounded;
    if (category.contains('transport') || category.contains('uber') || category.contains('gas') || category.contains('car') || category.contains('fuel')) return Icons.directions_car_rounded;
    if (category.contains('shopping') || category.contains('amazon') || category.contains('retail') || category.contains('clothes')) return Icons.shopping_bag_rounded;
    if (category.contains('netflix') || category.contains('spotify') || category.contains('subscription') || category.contains('streaming')) return Icons.subscriptions_rounded;
    if (category.contains('health') || category.contains('medical') || category.contains('doctor') || category.contains('pharmacy')) return Icons.local_hospital_rounded;
    if (category.contains('home') || category.contains('rent') || category.contains('mortgage') || category.contains('electric') || category.contains('utility')) return Icons.home_rounded;
    if (category.contains('gym') || category.contains('fitness') || category.contains('sport')) return Icons.fitness_center_rounded;
    if (category.contains('travel') || category.contains('flight') || category.contains('hotel') || category.contains('vacation')) return Icons.flight_rounded;
    if (category.contains('coffee') || category.contains('cafe') || category.contains('tea')) return Icons.coffee_rounded;
    if (category.contains('education') || category.contains('school') || category.contains('book') || category.contains('tuition')) return Icons.school_rounded;
    if (category.contains('salary') || category.contains('payroll') || category.contains('wage')) return Icons.account_balance_wallet_rounded;
    if (category.contains('insurance')) return Icons.shield_rounded;
    if (category.contains('phone') || category.contains('mobile') || category.contains('internet')) return Icons.phone_android_rounded;
    return Icons.receipt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final color = isIncome
        ? Theme.of(context).colorScheme.primary
        : _colorForCategory(transaction.category);
    final displayCategory = transaction.category.isNotEmpty
        ? transaction.category[0].toUpperCase() + transaction.category.substring(1)
        : 'Uncategorized';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
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
                  child: Icon(
                    _iconForCategory(transaction.category),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayCategory,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          transaction.note!,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]
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
                child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
              ),
          ],
        ),
      ),
    );
  }
}
