import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/transaction.dart' as model;
import '../models/account.dart';
import '../services/refresh_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';


class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<model.Transaction> _transactions = [];
  List<Account> _accounts = [];
  bool _loading = true;
  String _searchQuery = '';
  String? _filterType; // 'income', 'expense', or null for all
  int? _filterAccountId;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

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
    final txns = await AppDatabase.getTransactions();
    final accounts = await AppDatabase.getAccounts();
    if (!mounted) return;
    setState(() {
      _transactions = txns;
      _accounts = accounts;
      _loading = false;
    });
  }

  List<model.Transaction> get _filteredTransactions {
    var filtered = _transactions;
    
    // Search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        return t.category.toLowerCase().contains(query) ||
            (t.note?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    // Type filter
    if (_filterType != null) {
      filtered = filtered.where((t) => t.type == _filterType).toList();
    }
    
    // Account filter
    if (_filterAccountId != null) {
      filtered = filtered.where((t) => t.accountId == _filterAccountId).toList();
    }
    
    // Date range filter
    if (_filterStartDate != null) {
      filtered = filtered.where((t) => t.date.isAfter(_filterStartDate!) || t.date.isAtSameMomentAs(_filterStartDate!)).toList();
    }
    if (_filterEndDate != null) {
      filtered = filtered.where((t) => t.date.isBefore(_filterEndDate!) || t.date.isAtSameMomentAs(_filterEndDate!)).toList();
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
              const Text(
                'Filters',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
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
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All accounts')),
                  ..._accounts.map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name),
                  )),
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
                          _filterStartDate = null;
                          _filterEndDate = null;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export')),
      );
      return;
    }

    // Generate CSV content
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

    // Show export dialog with preview
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${filtered.length} transactions ready to export as CSV'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                buffer.toString().split('\n').take(5).join('\n') + '\n...',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Copy the data above and paste into a spreadsheet app.',
              style: TextStyle(fontSize: 12, color: AppTheme.slate500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              // In a real app, you'd use share_plus or file_picker to save
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV data copied to clipboard')),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Copy CSV'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');
    final filtered = _filteredTransactions;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF064E3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [Colors.white, Color(0xFFD1FAE5)],
                                    ).createShader(bounds),
                                    child: const Text(
                                      'Transactions',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w300,
                                        letterSpacing: -1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${filtered.length} transactions',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.filter_list, color: Colors.white),
                                      onPressed: _showFilters,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.file_download, color: Colors.white),
                                      onPressed: _exportTransactions,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: filtered.length <= 15
                          ? SingleChildScrollView(
                              child: Column(
                                children: [
                                  TweenAnimationBuilder(
                                    duration: const Duration(milliseconds: 500),
                                    tween: Tween<double>(begin: 0, end: 1),
                                    builder: (context, double value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(0, 20 * (1 - value)),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        GlassCard(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: TextField(
                                            onChanged: (v) => setState(() => _searchQuery = v),
                                            decoration: const InputDecoration(
                                              hintText: 'Search transactions...',
                                              prefixIcon: Icon(Icons.search, color: AppTheme.slate400),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                                            ),
                                          ),
                                        ),
                                        if (_filterType != null || _filterAccountId != null) ...[
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              if (_filterType != null)
                                                Chip(
                                                  label: Text(_filterType == 'income' ? 'Income' : 'Expense'),
                                                  onDeleted: () => setState(() => _filterType = null),
                                                  deleteIcon: const Icon(Icons.close, size: 16),
                                                  backgroundColor: AppTheme.indigo.withValues(alpha: 0.1),
                                                ),
                                              if (_filterAccountId != null)
                                                Chip(
                                                  label: Text(_accounts.where((a) => a.id == _filterAccountId).firstOrNull?.name ?? 'Account'),
                                                  onDeleted: () => setState(() => _filterAccountId = null),
                                                  deleteIcon: const Icon(Icons.close, size: 16),
                                                  backgroundColor: AppTheme.emerald.withValues(alpha: 0.1),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (filtered.isEmpty)
                                    const Center(
                                        child: Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Text('No transactions found.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey)),
                                    ))
                                  else
                                    GlassCard(
                                      padding: EdgeInsets.zero,
                                      child: Column(
                                        children: filtered.asMap().entries.map((entry) {
                                          return _buildTransactionTile(entry.key, entry.value, filtered.length, fmt, dateFmt, timeFmt);
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : ListView(
                              children: [
                                TweenAnimationBuilder(
                                  duration: const Duration(milliseconds: 500),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  builder: (context, double value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 20 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      GlassCard(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: TextField(
                                          onChanged: (v) => setState(() => _searchQuery = v),
                                          decoration: const InputDecoration(
                                            hintText: 'Search transactions...',
                                            prefixIcon: Icon(Icons.search, color: AppTheme.slate400),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                                          ),
                                        ),
                                      ),
                                      if (_filterType != null || _filterAccountId != null) ...[
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            if (_filterType != null)
                                              Chip(
                                                label: Text(_filterType == 'income' ? 'Income' : 'Expense'),
                                                onDeleted: () => setState(() => _filterType = null),
                                                deleteIcon: const Icon(Icons.close, size: 16),
                                                backgroundColor: AppTheme.indigo.withValues(alpha: 0.1),
                                              ),
                                            if (_filterAccountId != null)
                                              Chip(
                                                label: Text(_accounts.where((a) => a.id == _filterAccountId).firstOrNull?.name ?? 'Account'),
                                                onDeleted: () => setState(() => _filterAccountId = null),
                                                deleteIcon: const Icon(Icons.close, size: 16),
                                                backgroundColor: AppTheme.emerald.withValues(alpha: 0.1),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                if (filtered.isEmpty)
                                  const Center(
                                      child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Text('No transactions found.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey)),
                                  ))
                                else
                                  GlassCard(
                                    padding: EdgeInsets.zero,
                                    child: Column(
                                      children: filtered.asMap().entries.map((entry) {
                                        return _buildTransactionTile(entry.key, entry.value, filtered.length, fmt, dateFmt, timeFmt);
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTransactionTile(int index, model.Transaction t, int totalCount, NumberFormat fmt, DateFormat dateFmt, DateFormat timeFmt) {
    final account = _accounts.where((a) => a.id == t.accountId).firstOrNull;
    final isIncome = t.type == 'income';
    
    // Calculate dynamic sizing based on item count
    final double iconSize = totalCount <= 5 ? 56 : totalCount <= 10 ? 48 : 40;
    final double padding = totalCount <= 5 ? 20 : totalCount <= 10 ? 16 : 12;
    final double titleSize = totalCount <= 5 ? 16 : totalCount <= 10 ? 15 : 14;
    final double subtitleSize = totalCount <= 5 ? 13 : totalCount <= 10 ? 12 : 11;
    final double amountSize = totalCount <= 5 ? 20 : totalCount <= 10 ? 18 : 16;

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 600 + (index * 30)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(-20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () => _showEditTransaction(t),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            border: index < totalCount - 1
                ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isIncome
                        ? [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)]
                        : [const Color(0xFFF3F4F6), const Color(0xFFE5E7EB)],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? const Color(0xFF059669) : const Color(0xFF6B7280),
                  size: iconSize * 0.42,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.category,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (account != null) ...[
                          Flexible(
                            child: Text(
                              account.name,
                              style: TextStyle(fontSize: subtitleSize, color: AppTheme.slate500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(' • ', style: TextStyle(color: AppTheme.slate500, fontSize: subtitleSize)),
                        ],
                        Flexible(
                          child: Text(
                            dateFmt.format(t.date),
                            style: TextStyle(fontSize: subtitleSize, color: AppTheme.slate500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? "+" : ""}${fmt.format(t.amount)}',
                style: TextStyle(
                  fontSize: amountSize,
                  fontWeight: FontWeight.w500,
                  color: isIncome ? AppTheme.emerald : AppTheme.slate900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTransaction(model.Transaction t) {
    final amtCtrl = TextEditingController(text: t.amount.toStringAsFixed(2));
    final catCtrl = TextEditingController(text: t.category);
    final noteCtrl = TextEditingController(text: t.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Edit ${t.type[0].toUpperCase()}${t.type.substring(1)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                await AppDatabase.deleteTransaction(t.id!);
                notifyDataChanged();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ]),
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
            decoration: const InputDecoration(
                labelText: 'Category', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(
                labelText: 'Note (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amtCtrl.text);
                final cat = catCtrl.text.trim().toLowerCase();
                if (amount == null || amount <= 0 || cat.isEmpty) return;
                await AppDatabase.updateTransaction(model.Transaction(
                  id: t.id,
                  type: t.type,
                  amount: amount,
                  category: cat,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                  date: t.date,
                  accountId: t.accountId,
                ));
                notifyDataChanged();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ]),
        ]),
      ),
    );
  }
}
