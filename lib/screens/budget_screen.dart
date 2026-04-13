import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/budget.dart';
import '../services/refresh_notifier.dart';
import '../widgets/category_picker.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Budget> _budgets = [];
  Map<String, double> _spent = {};
  double _income = 0;
  bool _loading = true;
  // Month navigation
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
    _load();
    appRefresh.addListener(_load);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final budgets = await AppDatabase.getBudgets(_month.month, _month.year);
    final spent = await AppDatabase.monthlyExpenseByCategory(_month.month, _month.year);
    final income = await AppDatabase.monthlyTotal('income', _month.month, _month.year);

    // Merge: spent categories with no budget row → show as unbudgeted
    final budgetCategories = {for (final b in budgets) b.category};
    final extra = spent.keys
        .where((c) => !budgetCategories.contains(c))
        .map((c) => Budget(
              category: c,
              limit: 0,
              month: _month.month,
              year: _month.year,
            ))
        .toList();

    if (!mounted) return;
    setState(() {
      _budgets = [...budgets, ...extra];
      _spent = spent;
      _income = income;
      _loading = false;
    });
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
      _loading = true;
    });
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return; // don't go into future
    setState(() {
      _month = next;
      _loading = true;
    });
    _load();
  }

  void _showEditDialog(Budget? existing) {
    // FIX: for unbudgeted rows (id==null, limit==0), category is known — pass it in
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final limCtrl = TextEditingController(
        text: existing != null && existing.limit > 0
            ? existing.limit.toStringAsFixed(2)
            : '');
    final isExisting = existing != null;
    final isUnbudgeted = isExisting && existing.id == null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isExisting ? 'Edit Budget' : 'Add Budget'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: catCtrl,
            // Disable rename for existing (both saved and unbudgeted)
            enabled: !isExisting,
            readOnly: !isExisting ? false : true,
            onTap: !isExisting ? () async {
              final picked = await showCategoryPicker(context,
                  current: catCtrl.text);
              if (picked != null) catCtrl.text = picked;
            } : null,
            decoration: InputDecoration(
              labelText: 'Category',
              suffixIcon: !isExisting
                  ? const Icon(Icons.arrow_drop_down)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: limCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly Limit',
              prefixText: '\$',
            ),
          ),
          if (isUnbudgeted)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'This category has spending but no limit set.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final cat = catCtrl.text.trim().toLowerCase();
              final lim = double.tryParse(limCtrl.text);
              if (cat.isEmpty || lim == null || lim < 0) return;
              // FIX: always upsert by category+month+year — id is irrelevant
              // because UNIQUE(category,month,year) handles dedup correctly
              await AppDatabase.upsertBudget(Budget(
                id: isUnbudgeted ? null : existing?.id,
                category: cat,
                limit: lim,
                month: _month.month,
                year: _month.year,
              ));
              notifyDataChanged();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalBudgeted = _budgets.fold(0.0, (s, b) => s + b.limit);
    final totalSpent = _spent.values.fold(0.0, (s, v) => s + v);
    final unallocated = _income - totalBudgeted;
    final isCurrentMonth = _month.month == DateTime.now().month &&
        _month.year == DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
            Text(DateFormat('MMM yyyy').format(_month)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: isCurrentMonth ? null : _nextMonth,
              color: isCurrentMonth ? Colors.grey : null,
            ),
          ],
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(null),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _IncomeSummaryCard(
                  income: _income,
                  budgeted: totalBudgeted,
                  spent: totalSpent,
                  unallocated: unallocated,
                ),
                const SizedBox(height: 16),
                if (_budgets.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No budgets yet.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ..._budgets.map((b) => _BudgetCard(
                        budget: b,
                        spent: _spent[b.category] ?? 0,
                        onEdit: () => _showEditDialog(b),
                      )),
              ],
            ),
    );
  }
}

// ── Income Summary Card ────────────────────────────────────────────────────────

class _IncomeSummaryCard extends StatelessWidget {
  final double income, budgeted, spent, unallocated;
  const _IncomeSummaryCard({
    required this.income,
    required this.budgeted,
    required this.spent,
    required this.unallocated,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    // FIX: two separate bars instead of stacked — much clearer visually
    final budgetedRatio = income > 0 ? (budgeted / income).clamp(0.0, 1.0) : 0.0;
    final spentRatio = income > 0 ? (spent / income).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This Month',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          // Row 1: Budgeted vs Income
          _BarRow(
            label: 'Budgeted',
            ratio: budgetedRatio,
            color: Colors.indigo,
            trailing: '${fmt.format(budgeted)} / ${fmt.format(income)}',
          ),
          const SizedBox(height: 8),
          // Row 2: Spent vs Income
          _BarRow(
            label: 'Spent',
            ratio: spentRatio,
            color: spent > income ? Colors.red : Colors.orange,
            trailing: '${fmt.format(spent)} / ${fmt.format(income)}',
          ),
          const Divider(height: 20),
          // Stats row
          Row(children: [
            _Stat('Income', income, Colors.green, fmt),
            _Stat('Budgeted', budgeted, Colors.indigo, fmt),
            _Stat('Spent', spent, spent > income ? Colors.red : Colors.orange, fmt),
            _Stat(
              'Free',
              unallocated,
              // FIX: show grey when no income logged yet, not alarming red
              income == 0
                  ? Colors.grey
                  : unallocated >= 0
                      ? Colors.teal
                      : Colors.red,
              fmt,
            ),
          ]),
        ]),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double ratio;
  final Color color;
  final String trailing;
  const _BarRow(
      {required this.label,
      required this.ratio,
      required this.color,
      required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(trailing, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 10,
          backgroundColor: color.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final NumberFormat fmt;
  const _Stat(this.label, this.value, this.color, this.fmt);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(fmt.format(value),
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

// ── Budget Card ───────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final double spent;
  final VoidCallback onEdit;

  const _BudgetCard(
      {required this.budget, required this.spent, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final isUnbudgeted = budget.limit == 0;
    final ratio =
        budget.limit > 0 ? (spent / budget.limit).clamp(0.0, 1.0) : 1.0;
    final over = !isUnbudgeted && spent > budget.limit;
    final color = isUnbudgeted
        ? Colors.grey
        : over
            ? Colors.red
            : ratio > 0.8
                ? Colors.orange
                : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Text(budget.category,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              if (isUnbudgeted)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('unbudgeted',
                      style: TextStyle(fontSize: 10, color: Colors.grey)),
                ),
            ]),
            Row(children: [
              if (over)
                const Icon(Icons.warning_amber, color: Colors.red, size: 18),
              IconButton(
                  icon: const Icon(Icons.edit, size: 18), onPressed: onEdit),
            ]),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio,
            color: color,
            backgroundColor: color.withOpacity(0.15),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Spent: ${fmt.format(spent)}',
                style: TextStyle(color: color, fontSize: 13)),
            Text(
              isUnbudgeted
                  ? 'Tap edit to set limit'
                  : 'Limit: ${fmt.format(budget.limit)}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ]),
          if (over)
            Text('Over by ${fmt.format(spent - budget.limit)}',
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          if (!isUnbudgeted && !over)
            Text('Remaining: ${fmt.format(budget.limit - spent)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ),
    );
  }
}
