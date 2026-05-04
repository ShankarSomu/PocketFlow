import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../db/database.dart';
import '../../models/account.dart';
import '../../models/transaction.dart' as model;
import '../../services/refresh_notifier.dart';
import 'package:pocket_flow/sms_engine/feedback/sms_feedback_service.dart';
import 'package:pocket_flow/sms_engine/rules/sms_correction_service.dart';
import '../../services/time_filter.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/empty_states.dart';
import '../../widgets/error_state_widget.dart';
import '../shared/shared.dart';
import 'components/transactions_components.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    this.initialFilterType,
    this.initialAccountId,
    this.initialCategory,
    this.initialFilterNeedsReview,
  });
  final String? initialFilterType;
  final int? initialAccountId;
  final String? initialCategory;
  final bool? initialFilterNeedsReview;

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
  final TextEditingController _searchController = TextEditingController();
  String? _filterType;
  String? _filterCategory;
  int? _filterAccountId;
  String? _filterSourceType;
  bool? _filterNeedsReview;
  
  // Intelligence stats
  int _pendingActionsCount = 0;
  int _transfersCount = 0;
  int _patternsCount = 0;

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialFilterType;
    _filterAccountId = widget.initialAccountId;
    _filterCategory = widget.initialCategory;
    _filterNeedsReview = widget.initialFilterNeedsReview;
    _load();
    appRefresh.addListener(_load);
    appTimeFilter.addListener(_load);
    // If opened with needs-review filter, load all transactions (no date limit)
    if (widget.initialFilterNeedsReview == true) {
      _loadAllForReview();
    }
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    appTimeFilter.removeListener(_load);
    _searchController.dispose();
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
      
      // Fetch intelligence stats
      int pendingCount = 0;
      int transferCount = 0;
      int patternCount = 0;
      
      try {
        final db = await AppDatabase.db();
        
        // Count needs_review transactions (all time, not filtered by date)
        try {
          final reviewResult = await db.rawQuery(
            "SELECT COUNT(*) as count FROM transactions WHERE needs_review = 1 AND deleted_at IS NULL AND source_type = 'sms'",
          );
          pendingCount = reviewResult.first['count'] as int? ?? 0;
        } catch (e) {
          pendingCount = 0;
        }
        
        try {
          final transferResult = await db.rawQuery(
            'SELECT COUNT(*) as count FROM transfer_pairs WHERE status = ?',
            ['pending'],
          );
          transferCount = transferResult.first['count'] as int? ?? 0;
        } catch (e) {
          transferCount = 0;
        }
        
        try {
          final patternResult = await db.rawQuery(
            'SELECT COUNT(*) as count FROM recurring_patterns WHERE status = ?',
            ['pending'],
          );
          patternCount = patternResult.first['count'] as int? ?? 0;
        } catch (e) {
          patternCount = 0;
        }
      } catch (e) {
        // Database error - set all to 0
        pendingCount = 0;
        transferCount = 0;
        patternCount = 0;
      }
      
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _accounts = accounts;
        _accountBalances = balances;
        _pendingActionsCount = pendingCount;
        _transfersCount = transferCount;
        _patternsCount = patternCount;
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
            (t.note?.toLowerCase().contains(query) ?? false) ||
            (t.merchant?.toLowerCase().contains(query) ?? false) ||
            t.amount.toString().contains(query);
      }).toList();
    }
    if (_filterType != null) {
      filtered = filtered.where((t) => t.type == _filterType).toList();
    }
    if (_filterCategory != null) {
      filtered = filtered.where((t) => t.category.toLowerCase() == _filterCategory!.toLowerCase()).toList();
    }
    if (_filterAccountId != null) {
      filtered = filtered.where((t) => t.accountId == _filterAccountId).toList();
    }
    if (_filterSourceType != null) {
      filtered = filtered.where((t) => t.sourceType == _filterSourceType).toList();
    }
    if (_filterNeedsReview != null && _filterNeedsReview!) {
      filtered = filtered.where((t) => t.requiresReview).toList();
    }
    return filtered;
  }

  bool get _hasActiveFilters =>
      _filterType != null ||
      _filterCategory != null ||
      _filterAccountId != null ||
      _filterSourceType != null ||
      (_filterNeedsReview ?? false) ||
      _searchQuery.isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _filterType = null;
      _filterCategory = null;
      _filterAccountId = null;
      _filterSourceType = null;
      _filterNeedsReview = null;
      _searchQuery = '';
      _searchController.clear();
      _searchVisible = false;
      _carouselIdx = 0;
    });
    // Reload with date filter restored
    _load();
  }

  /// Load ALL transactions (ignoring date filter) to show needs-review items
  /// which may have dates outside the current time filter window.
  Future<void> _loadAllForReview() async {
    try {
      final allTransactions = await AppDatabase.getTransactions();
      if (!mounted) return;
      setState(() {
        _transactions = allTransactions;
      });
    } catch (_) {
      // Silently fall back to current list
    }
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
              const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              const Text('Type', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filterType == null,
                    onSelected: (v) => setLocal(() => _filterType = null),
                  ),
                  FilterChip(
                    label: const Text('Income'),
                    selected: _filterType == 'income',
                    onSelected: (v) => setLocal(() => _filterType = v ? 'income' : null),
                  ),
                  FilterChip(
                    label: const Text('Expense'),
                    selected: _filterType == 'expense',
                    onSelected: (v) => setLocal(() => _filterType = v ? 'expense' : null),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Account', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: _filterAccountId,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: [
                  const DropdownMenuItem(child: Text('All accounts')),
                  ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (v) => setLocal(() => _filterAccountId = v),
              ),
              const SizedBox(height: 16),
              const Text('Source', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _filterSourceType,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All sources')),
                  DropdownMenuItem(value: 'sms', child: Text('📱 SMS')),
                  DropdownMenuItem(value: 'manual', child: Text('✏️ Manual')),
                  DropdownMenuItem(value: 'recurring', child: Text('🔄 Recurring')),
                  DropdownMenuItem(value: 'import', child: Text('📁 Imported')),
                ],
                onChanged: (v) => setLocal(() => _filterSourceType = v),
              ),
              const SizedBox(height: 16),
              const Text('Review Status', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filterNeedsReview == null,
                    onSelected: (v) => setLocal(() => _filterNeedsReview = null),
                  ),
                  FilterChip(
                    label: const Text('⚠️ Needs Review'),
                    selected: _filterNeedsReview == true,
                    onSelected: (v) => setLocal(() => _filterNeedsReview = v ? true : null),
                  ),
                ],
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
                          _filterSourceType = null;
                          _filterNeedsReview = null;
                        });
                      },
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      child: const Text('Apply'),
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
                        message: _error,
                        onRetry: _load,
                      )
                    : Column(
                children: [
                  const ScreenHeader(
                    'Transactions',
                    icon: Icons.receipt_long_rounded,
                    subtitle: 'All income and expenses',
                  ),
                  // -- Search bar (visible when toggled) --
                  if (_searchVisible)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search by category, note, merchant…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() {
                                    _searchVisible = false;
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  // -- Pending actions banner --
                  if (_pendingActionsCount > 0)
                    _PendingActionsBanner(
                      count: _pendingActionsCount,
                      onTap: () async {
                        // Load all transactions (no date filter) then show needs-review
                        await _loadAllForReview();
                        if (mounted) {
                          setState(() {
                            _filterNeedsReview = true;
                            _filterSourceType = null; // Don't restrict to SMS only
                          });
                        }
                      },
                    ),
                  // -- Account Carousel --
                  if (_accounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TransactionAccountCarousel(
                        accounts: _accounts,
                        balances: _accountBalances,
                        carouselIdx: _carouselIdx,
                        hasIntelligence: true, // Always show intelligence card
                        pendingActionsCount: _pendingActionsCount,
                        transfersCount: _transfersCount,
                        patternsCount: _patternsCount,
                        onIndexChanged: (i) {
                          setState(() {
                            _carouselIdx = i;
                            // Intelligence card is at index accounts.length + 1
                            if (i == _accounts.length + 1) {
                              // Don't filter when on intelligence card
                              _filterAccountId = null;
                            } else {
                              _filterAccountId = i == 0 ? null : _accounts[i - 1].id;
                            }
                          });
                        },
                        fmt: fmt,
                      ),
                    ),
                  // -- Active filter chips (type only) --
                  if (_filterType != null || _filterNeedsReview == true)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (_filterNeedsReview == true)
                            Chip(
                              label: const Text('⚠️ Needs Review',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              onDeleted: _clearAllFilters,
                              deleteIcon: const Icon(Icons.close, size: 14),
                              backgroundColor: Theme.of(context).colorScheme.errorContainer,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          if (_filterType != null)
                          Chip(
                            label: Text(_filterType == 'income' ? '? Income' : '? Expense',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            onDeleted: () => setState(() => _filterType = null),
                            deleteIcon: const Icon(Icons.close, size: 14),
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
                        ? (_transactions.isEmpty
                            ? EmptyStates.transactions(context, onAdd: _showAddTransactionForm)
                            : _NoFilterResultsState(
                                searchQuery: _searchQuery,
                                hasFilters: _hasActiveFilters,
                                onClearFilters: _clearAllFilters,
                              ))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                              itemCount: groupKeys.length,
                              addAutomaticKeepAlives: false,
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
                    icon: Icons.search_rounded,
                    label: 'Search',
                    onPressed: () => setState(() {
                      _searchVisible = !_searchVisible;
                      if (!_searchVisible) {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    }),
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
                const Text('Add Transaction',
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
                    if (picked != null) {
                      setLocal(() => catCtrl.text = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (_accounts.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    initialValue: accountId,
                    decoration: const InputDecoration(
                      labelText: 'Account',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          child: Text('No account')),
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
                    if (picked != null) {
                      setLocal(() => selectedDate = picked);
                    }
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
                            size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, yyyy').format(selectedDate),
                          style: const TextStyle(fontSize: 15),
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
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final amount = double.tryParse(amtCtrl.text);
                        final category = catCtrl.text.trim();
                        if (amount == null ||
                            amount <= 0 ||
                            category.isEmpty) {
                          return;
                        }
                        await AppDatabase.insertTransaction(
                          model.Transaction(
                            type: type,
                            amount: amount,
                            category: category,
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                            date: selectedDate,
                            accountId: accountId!,
                          ),
                        );
                        notifyDataChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Add'),
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

  Future<void> _showEditTransaction(model.Transaction transaction) async {
    // Navigate to comprehensive transaction detail screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(transaction: transaction),
      ),
    );
    
    // Reload data after returning from detail screen
    await _load();
  }
  
  // Legacy modal edit (keep for quick edits if needed)
  void _showQuickEditModal(model.Transaction transaction) {
    final amtCtrl = TextEditingController(text: transaction.amount.toStringAsFixed(2));
    final catCtrl = TextEditingController(text: transaction.category);
    final noteCtrl = TextEditingController(text: transaction.note ?? '');
    
    // Feedback state
    bool feedbackSubmitted = false;
    bool? userFeedback; // true = correct, false = disputed

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit ${transaction.type[0].toUpperCase()}${transaction.type.substring(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                
                // Feedback section (only for SMS transactions)
                if (transaction.smsSource != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Is this classification correct?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!feedbackSubmitted)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    // Mark as correct
                                    await SmsCorrectionService.markAsCorrect(
                                      transactionId: transaction.id!,
                                      smsText: transaction.smsSource!,
                                      category: transaction.category,
                                      transactionType: transaction.type,
                                    );
                                    setModalState(() {
                                      feedbackSubmitted = true;
                                      userFeedback = true;
                                    });
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: const Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.white),
                                              SizedBox(width: 8),
                                              Text('Thanks! This helps improve accuracy'),
                                            ],
                                          ),
                                          backgroundColor: Colors.green[700],
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.thumb_up_outlined),
                                  label: const Text('Correct'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    // Mark as disputed
                                    await SmsCorrectionService.markAsDisputed(transaction.id!);
                                    setModalState(() {
                                      feedbackSubmitted = true;
                                      userFeedback = false;
                                    });
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      _showDisputeActionSheet(transaction);
                                    }
                                  },
                                  icon: const Icon(Icons.thumb_down_outlined),
                                  label: const Text('Wrong'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (feedbackSubmitted && userFeedback == true)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Marked as correct - Thanks!',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (feedbackSubmitted && userFeedback == false && transaction.userDisputed)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Marked as disputed - Choose action below',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Display extracted bank and account identifier
                if (transaction.extractedBank != null || transaction.extractedAccountIdentifier != null) ...[
                  const SizedBox(height: 12),
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
                            Icon(Icons.account_balance_outlined, 
                              size: 16, 
                              color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Extracted Account Info',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (transaction.extractedBank != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.account_balance,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                const SizedBox(width: 6),
                                Text(
                                  'Bank: ${transaction.extractedBank}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (transaction.extractedAccountIdentifier != null)
                          Row(
                            children: [
                              Icon(Icons.tag,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                              const SizedBox(width: 6),
                              Text(
                                'Account #: ${transaction.extractedAccountIdentifier}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amtCtrl.text);
                      final category = catCtrl.text.trim();
                      if (amount == null || amount <= 0 || category.isEmpty) return;
                      
                      // Check if user edited the category (for SMS transactions)
                      final categoryChanged = transaction.smsSource != null && 
                                            category != transaction.category;
                      
                      await AppDatabase.updateTransaction(model.Transaction(
                        id: transaction.id,
                        type: transaction.type,
                        amount: amount,
                        category: category,
                        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                        date: transaction.date,
                        accountId: transaction.accountId,
                      ));
                      
                      // If category was changed on SMS transaction, record as edit feedback
                      if (categoryChanged) {
                        await SmsCorrectionService.recordEdit(
                          transactionId: transaction.id!,
                          smsText: transaction.smsSource!,
                          originalCategory: transaction.category,
                          newCategory: category,
                          transactionType: transaction.type,
                        );
                        await TransactionFeedbackService.recordCorrection(
                          transaction: transaction,
                          fieldName: 'category',
                          originalValue: transaction.category,
                          correctedValue: category,
                        );
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

  void _showDisputeActionSheet(model.Transaction transaction) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                const Text(
                  'What\'s wrong with this transaction?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose an action to help improve future classifications',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            
            // Edit Category
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Category'),
              subtitle: const Text('Change to correct category'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditTransaction(transaction);
              },
            ),
            const Divider(height: 1),
            
            // Not a Transaction
            ListTile(
              leading: Icon(Icons.block, color: Theme.of(context).colorScheme.error),
              title: const Text('Not a Transaction'),
              subtitle: const Text('Block this type of SMS'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Block this SMS type?'),
                    content: const Text(
                      'This will:\n'
                      '• Delete this transaction\n'
                      '• Block similar SMS in the future\n\n'
                      'Are you sure?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('Block'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true && transaction.smsSource != null) {
                  await SmsCorrectionService.markAsNotTransaction(
                    transactionId: transaction.id!,
                    smsText: transaction.smsSource!,
                  );
                  
                  // Close the action sheet
                  if (ctx.mounted) Navigator.pop(ctx);
                  
                  // Refresh data
                  notifyDataChanged();
                  
                  // Show confirmation
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.block, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Transaction blocked and deleted'),
                          ],
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
            const Divider(height: 1),
            
            // Block All Similar - NEW
            ListTile(
              leading: Icon(Icons.delete_sweep, color: Theme.of(context).colorScheme.error),
              title: const Text('Block All Similar'),
              subtitle: const Text('Find and delete similar transactions'),
              onTap: () async {
                Navigator.pop(ctx);
                await _blockAllSimilar(transaction);
              },
            ),
            const Divider(height: 1),
            
            // Undo Dispute
            ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Undo Dispute'),
              subtitle: const Text('Actually, it\'s correct'),
              onTap: () async {
                await SmsCorrectionService.undoDispute(transaction.id!);
                Navigator.pop(ctx);
                notifyDataChanged();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Dispute removed'),
                        ],
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const Divider(height: 1),
            
            // Dismiss
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Dismiss'),
              subtitle: const Text('I\'ll decide later'),
              onTap: () => Navigator.pop(ctx),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  Future<void> _blockAllSimilar(model.Transaction transaction) async {
    if (transaction.smsSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This transaction doesn\'t have SMS source')),
      );
      return;
    }
    
    // Find similar transactions
    final similarTransactions = await SmsCorrectionService.findSimilarTransactions(
      transaction.smsSource!,
    );
    
    // Remove the current transaction from the list (we'll delete it separately)
    final otherSimilar = similarTransactions.where((t) => t.id != transaction.id).toList();
    final totalCount = otherSimilar.length + 1; // +1 for current transaction
    
    if (totalCount == 1) {
      // No similar transactions found, just show regular block dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No similar transactions found. Use "Not a Transaction" instead.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Show confirmation dialog with preview
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Block $totalCount Transactions?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will delete:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('• Current transaction'),
              Text('• ${otherSimilar.length} similar SMS transaction${otherSimilar.length != 1 ? 's' : ''}'),
              const SizedBox(height: 16),
              const Text(
                'Preview:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Show current transaction first
              _buildTransactionPreview(transaction),
              // Show up to 4 similar transactions
              ...otherSimilar.take(4).map((t) => _buildTransactionPreview(t)),
              if (otherSimilar.length > 4)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '... and ${otherSimilar.length - 4} more',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('Delete $totalCount Transaction${totalCount != 1 ? 's' : ''}'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Delete all similar transactions
      final deletedCount = await SmsCorrectionService.markAllSimilarAsNotTransaction(
        smsText: transaction.smsSource!,
      );
      
      // Refresh data
      notifyDataChanged();
      
      // Show confirmation
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Deleted $deletedCount transaction${deletedCount != 1 ? 's' : ''} and blocked pattern'),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  Widget _buildTransactionPreview(model.Transaction t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '${DateFormat.MMMd().format(t.date)} - ${t.category} - ₹${t.amount.toStringAsFixed(2)}',
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets for TransactionsScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Banner shown at the top of the transactions list when pending SMS actions exist.
class _PendingActionsBanner extends StatelessWidget {
  const _PendingActionsBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sms_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count SMS ${count == 1 ? 'transaction needs' : 'transactions need'} review',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    'Tap to review and confirm',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onTertiaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state shown when filters/search return no results but transactions exist.
class _NoFilterResultsState extends StatelessWidget {
  const _NoFilterResultsState({
    required this.hasFilters,
    required this.onClearFilters,
    this.searchQuery = '',
  });
  final String searchQuery;
  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final isSearch = searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearch ? Icons.search_off_rounded : Icons.filter_list_off_rounded,
                size: 40,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearch ? 'No results for "$searchQuery"' : 'No transactions match',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Try a different search term or clear the search.'
                  : 'Try adjusting or clearing your active filters.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
