import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/haptic_feedback.dart';
import '../../db/database.dart';
import '../../models/budget.dart';
import '../../services/refresh_notifier.dart';
import '../../services/theme_service.dart';
import '../../services/time_filter.dart';
import '../../theme/app_color_scheme.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/empty_states.dart';
import '../../widgets/error_state_widget.dart';
import '../shared/shared.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _loading = true;
  String? _error;
  List<Budget> _budgets = [];
  Map<String, double> _spentByCategory = {};
  double _income = 0;

  @override
  void initState() {
    super.initState();
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
      final budgets = await AppDatabase.getBudgets(filter.budgetMonth, filter.budgetYear);
      final spent = await AppDatabase.rangeExpenseByCategory(filter.from, filter.to);
      final income = await AppDatabase.rangeTotal('income', filter.from, filter.to);
      final budgetCategories = {for (final b in budgets) b.category};
      final extra = spent.keys
          .where((c) => !budgetCategories.contains(c))
          .map((c) => Budget(category: c, limit: 0, month: filter.budgetMonth, year: filter.budgetYear))
          .toList();

      if (!mounted) return;
      setState(() {
        _budgets = [...budgets, ...extra];
        _spentByCategory = spent;
        _income = income;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load budgets: $e';
        _loading = false;
      });
    }
  }

  // Month navigation removed; now uses global time filter only.

  String _emojiForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('dining') || cat.contains('restaurant') || cat.contains('grocery')) return '🍔';
    if (cat.contains('transport') || cat.contains('car') || cat.contains('uber') || cat.contains('fuel')) return '🚗';
    if (cat.contains('shopping') || cat.contains('clothes') || cat.contains('amazon')) return '🛍️';
    if (cat.contains('entertainment') || cat.contains('netflix') || cat.contains('streaming')) return '🎬';
    if (cat.contains('utilities') || cat.contains('electric') || cat.contains('water') || cat.contains('internet')) return '⚡';
    if (cat.contains('health') || cat.contains('medical') || cat.contains('doctor') || cat.contains('pharmacy')) return '💊';
    if (cat.contains('home') || cat.contains('rent') || cat.contains('mortgage')) return '🏠';
    if (cat.contains('education') || cat.contains('school') || cat.contains('book')) return '📚';
    if (cat.contains('insurance')) return '🛡️';
    if (cat.contains('travel') || cat.contains('flight') || cat.contains('hotel')) return '✈️';
    if (cat.contains('gift') || cat.contains('donation')) return '🎁';
    if (cat.contains('phone') || cat.contains('mobile')) return '📱';
    if (cat.contains('coffee') || cat.contains('cafe')) return '☕';
    if (cat.contains('gym') || cat.contains('fitness') || cat.contains('sport')) return '💪';
    if (cat.contains('income') || cat.contains('salary')) return '💰';
    return '📦';
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
            if (isExisting && existing.id == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('This category has spending but no limit yet.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
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
              final filter = appTimeFilter.current;
              await AppDatabase.upsertBudget(Budget(
                id: isExisting ? existing.id : null,
                category: category,
                limit: limit,
                month: filter.budgetMonth,
                year: filter.budgetYear,
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

  String _periodLabel() {
    return appTimeFilter.current.label;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final totalLimit = _budgets.fold(0.0, (sum, b) => sum + b.limit);
    final totalSpent = _spentByCategory.values.fold(0.0, (sum, v) => sum + v);
    final overCount = _budgets.where((b) => b.limit > 0 && (_spentByCategory[b.category] ?? 0) > b.limit).length;
    final progress = totalLimit <= 0 ? 0.0 : (totalSpent / totalLimit).clamp(0.0, 1.0);
    final onBudget = _budgets.where((b) => b.limit > 0 && (_spentByCategory[b.category] ?? 0) <= b.limit).toList();
    final overBudget = _budgets.where((b) => b.limit > 0 && (_spentByCategory[b.category] ?? 0) > b.limit).toList();
    final untracked = _budgets.where((b) => b.limit <= 0).toList();

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
                    'Budget',
                    icon: Icons.pie_chart_rounded,
                    subtitle: 'Overall spending vs limits',
                  ),
                  // -- Summary Card --
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
                  // -- Budget List --
                  Expanded(
                    child: _budgets.isEmpty
                        ? EmptyStates.budgets(context, onAdd: () async {
                            await HapticFeedbackHelper.lightImpact();
                            _showEditDialog(null);
                          })
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                              children: [
                                ...onBudget.map((b) => _BudgetItem(
                                      budget: b,
                                      spent: _spentByCategory[b.category] ?? 0,
                                      emoji: _emojiForCategory(b.category),
                                      fmt: fmt,
                                      showDivider: false,
                                      onTap: () => _showEditDialog(b),
                                    )),
                                if (overBudget.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  Text('Over Budget', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).extension<AppColorScheme>()!.error)),
                                  ...overBudget.map((b) => _BudgetItem(
                                        budget: b,
                                        spent: _spentByCategory[b.category] ?? 0,
                                        emoji: _emojiForCategory(b.category),
                                        fmt: fmt,
                                        showDivider: false,
                                        onTap: () => _showEditDialog(b),
                                      )),
                                ],
                                if (untracked.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  Text('Untracked', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                                  ...untracked.map((b) => _BudgetItem(
                                        budget: b,
                                        spent: _spentByCategory[b.category] ?? 0,
                                        emoji: _emojiForCategory(b.category),
                                        fmt: fmt,
                                        showDivider: false,
                                        onTap: () => _showEditDialog(b),
                                      )),
                                ],
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              child: const CalendarFab(),
            ),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              right: 16,
              child: SpeedDialFab(
                actions: [
                  SpeedDialAction(
                    icon: Icons.add,
                    label: 'Add Budget',
                    onPressed: () => _showEditDialog(null),
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

// -----------------------------------------------------------------------------

class _BudgetSummaryCard extends StatelessWidget {

  const _BudgetSummaryCard({
    required this.totalSpent,
    required this.totalLimit,
    required this.progress,
    required this.overCount,
    required this.income,
    required this.fmt,
  });
  final double totalSpent;
  final double totalLimit;
  final double progress;
  final int overCount;
  final double income;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final remaining = totalLimit - totalSpent;
    final isOver = remaining < 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ThemeService.instance.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Spent', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              if (overCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).extension<AppColorScheme>()!.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$overCount over',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt.format(totalSpent),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/ ${fmt.format(totalLimit)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8), fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary,
                ),
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
                  color: isOver ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryPill(
                  label: 'Income',
                  amount: fmt.format(income),
                  icon: Icons.arrow_downward_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
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
  const _SummaryPill({required this.label, required this.amount, required this.icon, required this.color});
  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(amount,
                    style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

/// Section ? label header + white card of _BudgetItem rows.
class _BudgetSection extends StatelessWidget {

  const _BudgetSection({
    required this.label,
    required this.items,
    required this.spentByCategory,
    required this.emojiFor,
    required this.fmt,
    required this.onTap,
  });
  final String label;
  final List<Budget> items;
  final Map<String, double> spentByCategory;
  final String Function(String) emojiFor;
  final NumberFormat fmt;
  final void Function(Budget) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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

// -----------------------------------------------------------------------------

/// Single budget row: icon circle | category | spent/limit + inline progress bar.
class _BudgetItem extends StatelessWidget {

  const _BudgetItem({
    required this.budget,
    required this.spent,
    required this.emoji,
    required this.fmt,
    required this.showDivider,
    required this.onTap,
  });
  final Budget budget;
  final double spent;
  final String emoji;
  final NumberFormat fmt;
  final bool showDivider;
  final VoidCallback onTap;

  static Color _colorForCategory(BuildContext context, String category) {
    final colorScheme = Theme.of(context).colorScheme;
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('restaurant') || c.contains('dining')) return colorScheme.secondary;
    if (c.contains('transport') || c.contains('car')) return colorScheme.primary;
    if (c.contains('shopping')) return colorScheme.primary.withValues(alpha: 0.7);
    if (c.contains('entertainment')) return colorScheme.error;
    if (c.contains('health') || c.contains('medical')) return colorScheme.tertiary;
    if (c.contains('home') || c.contains('rent')) return colorScheme.secondary;
    if (c.contains('education') || c.contains('school')) return colorScheme.primary.withValues(alpha: 0.6);
    if (c.contains('travel') || c.contains('flight')) return colorScheme.primary;
    if (c.contains('utilities') || c.contains('electric')) return colorScheme.secondary;
    if (c.contains('insurance')) return colorScheme.onSurface.withValues(alpha: 0.6);
    if (c.contains('phone') || c.contains('mobile')) return colorScheme.tertiary;
    return colorScheme.primary;
  }

  static IconData _iconForCategory(String category) {
    final c = category.toLowerCase();
    if (c.contains('food') || c.contains('restaurant') || c.contains('dining') ||
        c.contains('lunch') || c.contains('dinner') || c.contains('grocery') || c.contains('groceries')) {
      return Icons.restaurant_rounded;
    }
    if (c.contains('transport') || c.contains('car') || c.contains('uber') ||
        c.contains('gas') || c.contains('fuel')) {
      return Icons.directions_car_rounded;
    }
    if (c.contains('shopping') || c.contains('amazon') || c.contains('retail') || c.contains('clothes')) {
      return Icons.shopping_bag_rounded;
    }
    if (c.contains('entertainment') || c.contains('netflix') || c.contains('streaming') ||
        c.contains('subscription')) {
      return Icons.subscriptions_rounded;
    }
    if (c.contains('health') || c.contains('medical') || c.contains('doctor') || c.contains('pharmacy')) {
      return Icons.local_hospital_rounded;
    }
    if (c.contains('home') || c.contains('rent') || c.contains('mortgage')) {
      return Icons.home_rounded;
    }
    if (c.contains('education') || c.contains('school') || c.contains('book') || c.contains('tuition')) {
      return Icons.school_rounded;
    }
    if (c.contains('travel') || c.contains('flight') || c.contains('hotel')) {
      return Icons.flight_rounded;
    }
    if (c.contains('coffee') || c.contains('cafe')) {
      return Icons.coffee_rounded;
    }
    if (c.contains('gym') || c.contains('fitness') || c.contains('sport')) {
      return Icons.fitness_center_rounded;
    }
    if (c.contains('utilities') || c.contains('electric') || c.contains('water')) {
      return Icons.bolt_rounded;
    }
    if (c.contains('insurance')) {
      return Icons.shield_rounded;
    }
    if (c.contains('phone') || c.contains('mobile') || c.contains('internet')) {
      return Icons.phone_android_rounded;
    }
    return Icons.receipt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final hasLimit = budget.limit > 0;
    final progress = hasLimit ? (spent / budget.limit).clamp(0.0, 1.0) : 0.0;
    final isOver = hasLimit && spent > budget.limit;
    final color = isOver ? Theme.of(context).colorScheme.error : _colorForCategory(context, budget.category);
    final displayCategory = budget.category.isNotEmpty
        ? budget.category[0].toUpperCase() + budget.category.substring(1)
        : 'Unbudgeted';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
            children: [
              Row(
                children: [
                  // Icon circle ? Material icon matching transaction screen style
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconForCategory(budget.category),
                      color: color,
                      size: 20,
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
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasLimit
                              ? '${fmt.format(spent)} / ${fmt.format(budget.limit)}'
                              : '${fmt.format(spent)} spent  no limit',
                          style: TextStyle(
                              fontSize: 12,
                              color: isOver ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
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
                          ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                          : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasLimit
                          ? '${(progress * 100).toStringAsFixed(0)}%'
                          : '?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isOver ? Theme.of(context).colorScheme.error : color,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasLimit) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOver ? Theme.of(context).colorScheme.error : color,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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


