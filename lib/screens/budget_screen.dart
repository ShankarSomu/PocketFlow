import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/budget.dart';
import '../services/refresh_notifier.dart';
import '../widgets/category_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';


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

  String _getEmojiForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('groceries') || cat.contains('restaurant') || cat.contains('dining')) return '🍔';
    if (cat.contains('transport') || cat.contains('gas') || cat.contains('fuel') || cat.contains('car')) return '🚗';
    if (cat.contains('shopping') || cat.contains('clothes') || cat.contains('retail')) return '🛍️';
    if (cat.contains('entertainment') || cat.contains('movie') || cat.contains('netflix') || cat.contains('spotify')) return '🎬';
    if (cat.contains('utilities') || cat.contains('electric') || cat.contains('water') || cat.contains('internet')) return '⚡';
    if (cat.contains('health') || cat.contains('medical') || cat.contains('doctor') || cat.contains('pharmacy')) return '🏥';
    if (cat.contains('home') || cat.contains('rent') || cat.contains('mortgage')) return '🏠';
    if (cat.contains('education') || cat.contains('school') || cat.contains('tuition')) return '📚';
    if (cat.contains('insurance')) return '🛡️';
    if (cat.contains('gym') || cat.contains('fitness') || cat.contains('sport')) return '💪';
    if (cat.contains('travel') || cat.contains('vacation') || cat.contains('flight')) return '✈️';
    if (cat.contains('pet')) return '🐾';
    if (cat.contains('gift') || cat.contains('donation')) return '🎁';
    if (cat.contains('phone') || cat.contains('mobile')) return '📱';
    return '💰';
  }

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
    final overCount = _budgets.where((b) => b.limit > 0 && (_spent[b.category] ?? 0) > b.limit).length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF064E3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    // Fixed Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                      'Budget',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w300,
                                        letterSpacing: -1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Track spending by category',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (overCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber, size: 16, color: AppTheme.error),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$overCount over budget',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                                  onPressed: _prevMonth,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                DateFormat('MMMM yyyy').format(_month),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                                  onPressed: isCurrentMonth ? null : _nextMonth,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Scrollable Content
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
                                child: Text(
                                  'No budgets yet.\nTap + to add one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.slate400),
                                ),
                              ),
                            )
                          else
                            ...(_budgets.asMap().entries.map((entry) {
                              final index = entry.key;
                              final b = entry.value;
                              final totalBudgets = _budgets.length;
                              return _BudgetCard(
                                budget: b,
                                spent: _spent[b.category] ?? 0,
                                emoji: _getEmojiForCategory(b.category),
                                onEdit: () => _showEditDialog(b),
                                totalBudgets: totalBudgets,
                                index: index,
                              );
                            })),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emerald.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showEditDialog(null),
          icon: const Icon(Icons.add),
          label: const Text('Add Budget'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
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
    final budgetedRatio = income > 0 ? (budgeted / income).clamp(0.0, 1.0) : 0.0;
    final spentRatio = income > 0 ? (spent / income).clamp(0.0, 1.0) : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF5F3FF)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.slate200.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This Month',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Income',
                          value: income,
                          color: AppTheme.emerald,
                          fmt: fmt,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Budgeted',
                          value: budgeted,
                          color: const Color(0xFF7C3AED),
                          fmt: fmt,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Spent',
                          value: spent,
                          color: spent > income ? AppTheme.error : const Color(0xFFF59E0B),
                          fmt: fmt,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Free',
                          value: unallocated,
                          color: income == 0
                              ? AppTheme.slate400
                              : unallocated >= 0
                                  ? const Color(0xFF14B8A6)
                                  : AppTheme.error,
                          fmt: fmt,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _BarRow(
                    label: 'Budgeted',
                    ratio: budgetedRatio,
                    color: const Color(0xFF7C3AED),
                    trailing: '${fmt.format(budgeted)} / ${fmt.format(income)}',
                  ),
                  const SizedBox(height: 12),
                  _BarRow(
                    label: 'Spent',
                    ratio: spentRatio,
                    color: spent > income ? AppTheme.error : const Color(0xFFF59E0B),
                    trailing: '${fmt.format(spent)} / ${fmt.format(income)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final NumberFormat fmt;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.slate500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fmt.format(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
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



// ── Budget Card ───────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final double spent;
  final String emoji;
  final VoidCallback onEdit;
  final int totalBudgets;
  final int index;

  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.emoji,
    required this.onEdit,
    required this.totalBudgets,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final isUnbudgeted = budget.limit == 0;
    final ratio =
        budget.limit > 0 ? (spent / budget.limit).clamp(0.0, 1.0) : 1.0;
    final over = !isUnbudgeted && spent > budget.limit;
    final color = isUnbudgeted
        ? AppTheme.slate400
        : over
            ? AppTheme.error
            : ratio > 0.8
                ? const Color(0xFFF59E0B)
                : AppTheme.emerald;

    // Dynamic sizing based on budget count
    final double iconSize = totalBudgets <= 5 ? 48 : totalBudgets <= 10 ? 40 : 36;
    final double cardPadding = totalBudgets <= 5 ? 20 : totalBudgets <= 10 ? 16 : 12;
    final double titleSize = totalBudgets <= 5 ? 16 : totalBudgets <= 10 ? 15 : 14;
    final double amountSize = totalBudgets <= 5 ? 13 : totalBudgets <= 10 ? 12 : 11;
    final double progressHeight = totalBudgets <= 5 ? 10 : totalBudgets <= 10 ? 8 : 6;
    final double spacing = totalBudgets <= 5 ? 12 : totalBudgets <= 10 ? 10 : 8;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 700 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(cardPadding),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: iconSize * 0.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.category,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: titleSize,
                            color: AppTheme.slate900,
                          ),
                        ),
                        if (totalBudgets <= 10)
                          const Text(
                            'This month',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.slate400,
                            ),
                          ),
                      ],
                    ),
                    if (isUnbudgeted && totalBudgets <= 10)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.slate200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'unbudgeted',
                          style: TextStyle(fontSize: 10, color: AppTheme.slate600),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    if (over && totalBudgets <= 10)
                      Icon(Icons.warning_amber, color: AppTheme.error, size: 18),
                    IconButton(
                      icon: Icon(Icons.edit, size: totalBudgets <= 10 ? 18 : 16),
                      onPressed: onEdit,
                      color: AppTheme.slate600,
                      padding: EdgeInsets.all(totalBudgets <= 10 ? 8 : 4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: spacing),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: progressHeight,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            SizedBox(height: spacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Spent: ${fmt.format(spent)}',
                    style: TextStyle(
                      color: color,
                      fontSize: amountSize,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Text(
                    isUnbudgeted
                        ? (totalBudgets <= 10 ? 'Tap edit to set limit' : 'No limit')
                        : 'Limit: ${fmt.format(budget.limit)}',
                    style: TextStyle(
                      fontSize: amountSize,
                      color: AppTheme.slate500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (over && totalBudgets <= 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Over by ${fmt.format(spent - budget.limit)}',
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (!isUnbudgeted && !over && totalBudgets <= 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Remaining: ${fmt.format(budget.limit - spent)}',
                  style: const TextStyle(
                    color: AppTheme.emerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
