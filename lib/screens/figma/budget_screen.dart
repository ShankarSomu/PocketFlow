import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../models/budget.dart';
import '../../services/refresh_notifier.dart';
import '../../widgets/category_picker.dart';
import '../../theme/app_theme.dart';
import 'shared.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _loading = true;
  List<Budget> _budgets = [];
  Map<String, double> _spentByCategory = {};
  double _income = 0;
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
    final budgetCategories = {for (final b in budgets) b.category};
    final extra = spent.keys
        .where((c) => !budgetCategories.contains(c))
        .map((c) => Budget(category: c, limit: 0, month: _month.month, year: _month.year))
        .toList();

    if (!mounted) return;
    setState(() {
      _budgets = [...budgets, ...extra];
      _spentByCategory = spent;
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
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _month = next;
      _loading = true;
    });
    _load();
  }

  String _emojiForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food')) return '🍔';
    if (cat.contains('transport')) return '🚗';
    if (cat.contains('shopping')) return '🛍️';
    if (cat.contains('entertainment')) return '🎬';
    if (cat.contains('utilities')) return '⚡';
    if (cat.contains('health')) return '🏥';
    if (cat.contains('home')) return '🏠';
    if (cat.contains('education')) return '📚';
    if (cat.contains('insurance')) return '🛡️';
    if (cat.contains('travel')) return '✈️';
    if (cat.contains('gift')) return '🎁';
    if (cat.contains('phone')) return '📱';
    return '💰';
  }

  Future<void> _showEditDialog(Budget? existing) async {
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final limCtrl = TextEditingController(text: existing != null && existing.limit > 0 ? existing.limit.toStringAsFixed(2) : '');
    final isExisting = existing != null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isExisting ? 'Edit Budget' : 'Add Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: catCtrl,
              enabled: !isExisting,
              decoration: InputDecoration(
                labelText: 'Category',
                suffixIcon: !isExisting ? const Icon(Icons.arrow_drop_down) : null,
              ),
              onTap: !isExisting
                  ? () async {
                      final picked = await showCategoryPicker(context, current: catCtrl.text);
                      if (picked != null) catCtrl.text = picked;
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: limCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monthly Limit', prefixText: '\$', border: OutlineInputBorder()),
            ),
            if (isExisting && existing!.id == null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('This category has spending but no limit yet.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final category = catCtrl.text.trim().toLowerCase();
              final limit = double.tryParse(limCtrl.text) ?? 0;
              if (category.isEmpty) return;
              await AppDatabase.upsertBudget(Budget(
                id: isExisting ? existing?.id : null,
                category: category,
                limit: limit,
                month: _month.month,
                year: _month.year,
              ));
              notifyDataChanged();
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime date) {
    return DateFormat.yMMM().format(date);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final totalLimit = _budgets.fold(0.0, (sum, b) => sum + b.limit);
    final totalSpent = _spentByCategory.values.fold(0.0, (sum, v) => sum + v);
    final overCount = _budgets.where((b) => b.limit > 0 && (_spentByCategory[b.category] ?? 0) > b.limit).length;
    final progress = totalLimit <= 0 ? 0.0 : (totalSpent / totalLimit).clamp(0.0, 1.0) as double;
    final onBudget = _budgets.where((b) => b.limit > 0 && (_spentByCategory[b.category] ?? 0) <= b.limit).toList();
    final overBudget = _budgets.where((b) => b.limit > 0 && (_spentByCategory[b.category] ?? 0) > b.limit).toList();
    final untracked = _budgets.where((b) => b.limit <= 0).toList();

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
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: const Icon(Icons.pie_chart_rounded, color: AppTheme.slate700, size: 20),
                        ),
                        const Expanded(
                          child: Text(
                            'Budget',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slate900),
                          ),
                        ),
                        // Month nav
                        GestureDetector(
                          onTap: _prevMonth,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: const Icon(Icons.chevron_left, color: AppTheme.slate700, size: 18),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Text(
                            _monthLabel(_month),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slate700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _nextMonth,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: const Icon(Icons.chevron_right, color: AppTheme.slate700, size: 18),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showEditDialog(null),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: AppTheme.emeraldGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Summary Card ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _BudgetSummaryCard(
                      totalSpent: totalSpent,
                      totalLimit: totalLimit,
                      progress: progress,
                      overCount: overCount,
                      income: _income,
                      fmt: fmt,
                    ),
                  ),
                  // ── Budget List ──
                  Expanded(
                    child: _budgets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pie_chart_outline_rounded, size: 56, color: AppTheme.slate300),
                                const SizedBox(height: 12),
                                const Text('No budgets set yet',
                                    style: TextStyle(color: AppTheme.slate500, fontSize: 15)),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () => _showEditDialog(null),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.emeraldGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('Add your first budget',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                              children: [
                                if (overBudget.isNotEmpty)
                                  _BudgetSection(
                                    label: 'Over Budget',
                                    items: overBudget,
                                    spentByCategory: _spentByCategory,
                                    emojiFor: _emojiForCategory,
                                    fmt: fmt,
                                    onTap: _showEditDialog,
                                  ),
                                if (onBudget.isNotEmpty)
                                  _BudgetSection(
                                    label: 'On Track',
                                    items: onBudget,
                                    spentByCategory: _spentByCategory,
                                    emojiFor: _emojiForCategory,
                                    fmt: fmt,
                                    onTap: _showEditDialog,
                                  ),
                                if (untracked.isNotEmpty)
                                  _BudgetSection(
                                    label: 'No Limit Set',
                                    items: untracked,
                                    spentByCategory: _spentByCategory,
                                    emojiFor: _emojiForCategory,
                                    fmt: fmt,
                                    onTap: _showEditDialog,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Components
// ─────────────────────────────────────────────────────────────────────────────

/// Summary card — dark gradient, total spent/limit, overall progress bar.
class _BudgetSummaryCard extends StatelessWidget {
  final double totalSpent;
  final double totalLimit;
  final double progress;
  final int overCount;
  final double income;
  final NumberFormat fmt;

  const _BudgetSummaryCard({
    required this.totalSpent,
    required this.totalLimit,
    required this.progress,
    required this.overCount,
    required this.income,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = totalLimit - totalSpent;
    final isOver = remaining < 0;

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
                child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Monthly Budget',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('Overall spending vs limits',
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
              const Spacer(),
              if (overCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$overCount over',
                      style: const TextStyle(
                          color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Total Spent', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt.format(totalSpent),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/ ${fmt.format(totalLimit)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? AppTheme.error : const Color(0xFF34D399),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryPill(
                  label: isOver ? 'Over by' : 'Remaining',
                  amount: fmt.format(remaining.abs()),
                  icon: isOver ? Icons.warning_rounded : Icons.savings_rounded,
                  color: isOver ? const Color(0xFFF87171) : const Color(0xFF34D399),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryPill(
                  label: 'Income',
                  amount: fmt.format(income),
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF34D399),
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
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
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

// ─────────────────────────────────────────────────────────────────────────────

/// Section — label header + white card of _BudgetItem rows.
class _BudgetSection extends StatelessWidget {
  final String label;
  final List<Budget> items;
  final Map<String, double> spentByCategory;
  final String Function(String) emojiFor;
  final NumberFormat fmt;
  final void Function(Budget) onTap;

  const _BudgetSection({
    required this.label,
    required this.items,
    required this.spentByCategory,
    required this.emojiFor,
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
            label,
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
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return _BudgetItem(
                budget: e.value,
                spent: spentByCategory[e.value.category] ?? 0.0,
                emoji: emojiFor(e.value.category),
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

// ─────────────────────────────────────────────────────────────────────────────

/// Single budget row: icon circle | category | spent/limit + inline progress bar.
class _BudgetItem extends StatelessWidget {
  final Budget budget;
  final double spent;
  final String emoji;
  final NumberFormat fmt;
  final bool showDivider;
  final VoidCallback onTap;

  const _BudgetItem({
    required this.budget,
    required this.spent,
    required this.emoji,
    required this.fmt,
    required this.showDivider,
    required this.onTap,
  });

  static Color _colorForCategory(String category) {
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('restaurant') || c.contains('dining')) return const Color(0xFFFF6B35);
    if (c.contains('transport') || c.contains('car')) return const Color(0xFF3B82F6);
    if (c.contains('shopping')) return const Color(0xFF8B5CF6);
    if (c.contains('entertainment')) return const Color(0xFFEF4444);
    if (c.contains('health') || c.contains('medical')) return const Color(0xFF06B6D4);
    if (c.contains('home') || c.contains('rent')) return const Color(0xFFF59E0B);
    if (c.contains('education') || c.contains('school')) return const Color(0xFF7C3AED);
    if (c.contains('travel') || c.contains('flight')) return const Color(0xFF0EA5E9);
    if (c.contains('utilities') || c.contains('electric')) return const Color(0xFFF59E0B);
    if (c.contains('insurance')) return const Color(0xFF64748B);
    if (c.contains('phone') || c.contains('mobile')) return const Color(0xFF10B981);
    return const Color(0xFF6366F1);
  }

  static IconData _iconForCategory(String category) {
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('restaurant') || c.contains('dining') ||
        c.contains('lunch') || c.contains('dinner') || c.contains('grocery') || c.contains('groceries'))
      return Icons.restaurant_rounded;
    if (c.contains('transport') || c.contains('car') || c.contains('uber') ||
        c.contains('gas') || c.contains('fuel'))
      return Icons.directions_car_rounded;
    if (c.contains('shopping') || c.contains('amazon') || c.contains('retail') || c.contains('clothes'))
      return Icons.shopping_bag_rounded;
    if (c.contains('entertainment') || c.contains('netflix') || c.contains('streaming') ||
        c.contains('subscription'))
      return Icons.subscriptions_rounded;
    if (c.contains('health') || c.contains('medical') || c.contains('doctor') || c.contains('pharmacy'))
      return Icons.local_hospital_rounded;
    if (c.contains('home') || c.contains('rent') || c.contains('mortgage'))
      return Icons.home_rounded;
    if (c.contains('education') || c.contains('school') || c.contains('book') || c.contains('tuition'))
      return Icons.school_rounded;
    if (c.contains('travel') || c.contains('flight') || c.contains('hotel'))
      return Icons.flight_rounded;
    if (c.contains('coffee') || c.contains('cafe'))
      return Icons.coffee_rounded;
    if (c.contains('gym') || c.contains('fitness') || c.contains('sport'))
      return Icons.fitness_center_rounded;
    if (c.contains('utilities') || c.contains('electric') || c.contains('water'))
      return Icons.bolt_rounded;
    if (c.contains('insurance'))
      return Icons.shield_rounded;
    if (c.contains('phone') || c.contains('mobile') || c.contains('internet'))
      return Icons.phone_android_rounded;
    return Icons.receipt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final hasLimit = budget.limit > 0;
    final progress = hasLimit ? (spent / budget.limit).clamp(0.0, 1.0) as double : 0.0;
    final isOver = hasLimit && spent > budget.limit;
    final color = isOver ? AppTheme.error : _colorForCategory(budget.category);
    final displayCategory = budget.category.isNotEmpty
        ? budget.category[0].toUpperCase() + budget.category.substring(1)
        : 'Unbudgeted';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                // Icon circle — Material icon matching transaction screen style
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconForCategory(budget.category),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title + sub
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayCategory,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slate900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasLimit
                            ? '${fmt.format(spent)} / ${fmt.format(budget.limit)}'
                            : '${fmt.format(spent)} spent · no limit',
                        style: TextStyle(
                            fontSize: 12,
                            color: isOver ? AppTheme.error : AppTheme.slate400),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // % badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOver
                        ? AppTheme.error.withOpacity(0.1)
                        : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasLimit
                        ? '${(progress * 100).toStringAsFixed(0)}%'
                        : '—',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isOver ? AppTheme.error : color,
                    ),
                  ),
                ),
              ],
            ),
            if (hasLimit) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AppTheme.slate100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOver ? AppTheme.error : color,
                    ),
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

