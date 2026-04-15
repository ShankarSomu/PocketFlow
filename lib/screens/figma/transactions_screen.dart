import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../db/database.dart';
import '../../models/transaction.dart' as model;
import '../../models/account.dart';
import '../../services/refresh_notifier.dart';
import '../../theme/app_theme.dart';
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
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final transactions = await AppDatabase.getTransactions();
    final accounts = await AppDatabase.getAccounts();
    if (!mounted) return;
    setState(() {
      _transactions = transactions;
      _accounts = accounts;
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
      backgroundColor: const Color(0xFFF7F5F0),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
            : Column(
                children: [
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() {
                                _searchVisible = !_searchVisible;
                                if (!_searchVisible) _searchQuery = '';
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _searchVisible ? AppTheme.emerald : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: AppTheme.cardShadow,
                                ),
                                child: Icon(
                                  _searchVisible ? Icons.close : Icons.search,
                                  color: _searchVisible ? Colors.white : AppTheme.slate700,
                                  size: 20,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Transactions',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slate900),
                              ),
                            ),
                            GestureDetector(
                              onTap: _showFilters,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: AppTheme.cardShadow,
                                ),
                                child: const Icon(Icons.tune_rounded, color: AppTheme.slate700, size: 20),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _exportTransactions,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.emeraldGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: AppTheme.cardShadow,
                                ),
                                child: const Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        // Collapsible search bar
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 200),
                          crossFadeState: _searchVisible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          firstChild: const SizedBox(height: 14),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: TextField(
                                autofocus: true,
                                onChanged: (v) => setState(() => _searchQuery = v),
                                decoration: const InputDecoration(
                                  hintText: 'Search by category or note…',
                                  hintStyle: TextStyle(color: AppTheme.slate400, fontSize: 14),
                                  prefixIcon: Icon(Icons.search, color: AppTheme.slate400, size: 20),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Account Carousel ──
                  if (_accounts.isNotEmpty)
                    Container(
                      height: 38,
                      margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _AccountChip(
                            label: 'All',
                            selected: _filterAccountId == null,
                            onTap: () => setState(() => _filterAccountId = null),
                          ),
                          ..._accounts.map((a) => _AccountChip(
                            label: a.name,
                            selected: _filterAccountId == a.id,
                            onTap: () => setState(() => _filterAccountId = a.id),
                          )),
                        ],
                      ),
                    ),
                  // ── Card Summary ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _CardSummary(
                      account: selectedAccount,
                      totalIncome: totalIncome,
                      totalExpense: totalExpense,
                      transactionCount: filtered.length,
                      fmt: fmt,
                    ),
                  ),
                  // ── Active filter chips (type only) ──
                  if (_filterType != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(_filterType == 'income' ? '↑ Income' : '↓ Expense',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            onDeleted: () => setState(() => _filterType = null),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            backgroundColor: AppTheme.emeraldLight,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ],
                      ),
                    ),
                  // ── Grouped Transaction List ──
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.slate300),
                                const SizedBox(height: 12),
                                const Text('No transactions found',
                                    style: TextStyle(color: AppTheme.slate500, fontSize: 15)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                Text('Edit ${transaction.type[0].toUpperCase()}${transaction.type.substring(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                child: const Text('Save'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Reusable Components
// ──────────────────────────────────────────────────────────────────────────────

class _AccountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AccountChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.emerald : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardShadow,
          border: selected ? null : Border.all(color: AppTheme.slate200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.slate700,
          ),
        ),
      ),
    );
  }
}

/// CardSummary — gradient card showing net balance and income/expense split.
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
        : '**** ────';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2E22), Color(0xFF14532D), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
                child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account?.name ?? 'All Accounts',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(masked, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Net Balance', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
          const SizedBox(height: 4),
          Text(fmt.format(net),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
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
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
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
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            dateLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.slate600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: transactions.asMap().entries.map((e) {
              final isLast = e.key == transactions.length - 1;
              final account = accounts.where((a) => a.id == e.value.accountId).firstOrNull;
              return _TransactionItem(
                transaction: e.value,
                account: account,
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

/// TransactionItem — single row: icon circle | title + subtitle | amount.
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

  static IconData _icon(String category, bool isIncome) {
    if (isIncome) return Icons.arrow_downward_rounded;
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('lunch') || c.contains('dinner') || c.contains('restaurant') || c.contains('grocery') || c.contains('groceries')) return Icons.restaurant_rounded;
    if (c.contains('transport') || c.contains('uber') || c.contains('gas') || c.contains('car') || c.contains('fuel')) return Icons.directions_car_rounded;
    if (c.contains('shopping') || c.contains('amazon') || c.contains('retail') || c.contains('clothes')) return Icons.shopping_bag_rounded;
    if (c.contains('netflix') || c.contains('spotify') || c.contains('subscription') || c.contains('streaming')) return Icons.subscriptions_rounded;
    if (c.contains('health') || c.contains('medical') || c.contains('doctor') || c.contains('pharmacy')) return Icons.local_hospital_rounded;
    if (c.contains('home') || c.contains('rent') || c.contains('mortgage') || c.contains('electric') || c.contains('utility')) return Icons.home_rounded;
    if (c.contains('gym') || c.contains('fitness') || c.contains('sport')) return Icons.fitness_center_rounded;
    if (c.contains('travel') || c.contains('flight') || c.contains('hotel') || c.contains('vacation')) return Icons.flight_rounded;
    if (c.contains('coffee') || c.contains('cafe') || c.contains('tea')) return Icons.coffee_rounded;
    if (c.contains('education') || c.contains('school') || c.contains('book') || c.contains('tuition')) return Icons.school_rounded;
    if (c.contains('salary') || c.contains('payroll') || c.contains('wage')) return Icons.account_balance_wallet_rounded;
    if (c.contains('insurance')) return Icons.shield_rounded;
    if (c.contains('phone') || c.contains('mobile') || c.contains('internet')) return Icons.phone_android_rounded;
    return Icons.receipt_rounded;
  }

  static Color _color(String category, bool isIncome) {
    if (isIncome) return const Color(0xFF10B981);
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('restaurant') || c.contains('lunch')) return const Color(0xFFFF6B35);
    if (c.contains('transport') || c.contains('car') || c.contains('uber')) return const Color(0xFF3B82F6);
    if (c.contains('shopping') || c.contains('amazon')) return const Color(0xFF8B5CF6);
    if (c.contains('netflix') || c.contains('streaming') || c.contains('subscription')) return const Color(0xFFEF4444);
    if (c.contains('health') || c.contains('medical')) return const Color(0xFF06B6D4);
    if (c.contains('home') || c.contains('rent')) return const Color(0xFFF59E0B);
    if (c.contains('gym') || c.contains('fitness')) return const Color(0xFF10B981);
    if (c.contains('travel') || c.contains('flight')) return const Color(0xFF0EA5E9);
    if (c.contains('coffee') || c.contains('cafe')) return const Color(0xFFB45309);
    if (c.contains('education') || c.contains('school')) return const Color(0xFF7C3AED);
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final color = _color(transaction.category, isIncome);
    final icon = _icon(transaction.category, isIncome);
    final timeStr = DateFormat('d MMM, h:mm a').format(transaction.date);

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
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.category,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        account != null ? '${account!.name} • $timeStr' : timeStr,
                        style: const TextStyle(fontSize: 12, color: AppTheme.slate400),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${isIncome ? '+' : '−'}${fmt.format(transaction.amount.abs())}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isIncome ? const Color(0xFF059669) : AppTheme.slate900,
                  ),
                ),
              ],
            ),
            if (transaction.note != null && transaction.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Text(
                    transaction.note!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.slate400, fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 56),
                child: Divider(height: 1, color: AppTheme.slate100),
              ),
          ],
        ),
      ),
    );
  }
}
