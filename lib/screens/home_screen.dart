import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/transaction.dart' as model;
import '../models/savings_goal.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../services/refresh_notifier.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _income = 0, _expenses = 0;
  double _totalAssets = 0, _totalDebt = 0;
  Map<String, double> _categorySpend = {};
  List<model.Transaction> _recent = [];
  List<SavingsGoal> _goals = [];
  List<Budget> _budgets = [];
  List<RecurringTransaction> _recurring = [];
  bool _loading = true;
  bool _isFuture = false;
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
    try {
      final now = DateTime.now();
      final isFuture = _month.year > now.year ||
          (_month.year == now.year && _month.month > now.month);

      double income;
      double expenses;
      Map<String, double> cats;
      List<model.Transaction> recent;

      if (isFuture) {
        // Project from recurring transactions
        final recurring = await AppDatabase.getRecurring();
        final monthStart = DateTime(_month.year, _month.month, 1);
        final monthEnd = DateTime(_month.year, _month.month + 1, 1);

        double projIncome = 0;
        double projExpense = 0;
        final projCats = <String, double>{};

        for (final r in recurring) {
          if (!r.isActive) continue;
          if (r.type == 'transfer' || r.type == 'goal') continue;
          // Check if this recurring hits within the month
          var due = DateTime(r.nextDueDate.year, r.nextDueDate.month, r.nextDueDate.day);
          // Advance due to find occurrences in this month
          while (due.isBefore(monthStart)) {
            due = r.nextAfter(due);
          }
          while (due.isBefore(monthEnd)) {
            if (r.type == 'income') {
              projIncome += r.amount;
            } else {
              projExpense += r.amount;
              projCats[r.category] = (projCats[r.category] ?? 0) + r.amount;
            }
            if (r.frequency == 'once') break;
            due = r.nextAfter(due);
          }
        }
        income = projIncome;
        expenses = projExpense;
        cats = projCats;
        recent = [];
      } else {
        income = await AppDatabase.monthlyTotal('income', _month.month, _month.year);
        expenses = await AppDatabase.monthlyTotal('expense', _month.month, _month.year);
        cats = await AppDatabase.monthlyExpenseByCategory(_month.month, _month.year);
        recent = await AppDatabase.getTransactions(
          from: DateTime(_month.year, _month.month, 1),
          to: DateTime(_month.year, _month.month + 1, 1)
              .subtract(const Duration(seconds: 1)),
        );
      }

      final goals = await AppDatabase.getGoals();
      final budgets = await AppDatabase.getBudgets(_month.month, _month.year);
      final recurringAll = await AppDatabase.getRecurring();
      final accounts = await AppDatabase.getAccounts();

      double assets = 0, debt = 0;
      for (final a in accounts) {
        final bal = await AppDatabase.accountBalance(a.id!, a);
        if (a.type == 'credit') debt += bal;
        else assets += bal;
      }

      if (!mounted) return;
      setState(() {
        _income = income;
        _expenses = expenses;
        _categorySpend = cats;
        _recent = recent.take(5).toList();
        _goals = goals;
        _budgets = budgets.where((b) => b.limit > 0).toList();
        _recurring = recurringAll.where((r) => r.isActive).toList();
        _totalAssets = assets;
        _totalDebt = debt;
        _isFuture = isFuture;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
      _loading = true;
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1);
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final isCurrentMonth = _month.month == DateTime.now().month &&
        _month.year == DateTime.now().year;
    final net = _income - _expenses;
    final netWorth = _totalAssets - _totalDebt;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
            Column(mainAxisSize: MainAxisSize.min, children: [Text(DateFormat('MMM yyyy').format(_month)), if (_isFuture) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)), child: const Text('PROJECTED', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold))) else if (isCurrentMonth) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)), child: const Text('CURRENT', style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)))]),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextMonth,
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Net Worth Card ──────────────────────────────────────
                  _NetWorthCard(
                    netWorth: netWorth,
                    assets: _totalAssets,
                    debt: _totalDebt,
                    fmt: fmt,
                  ),
                  const SizedBox(height: 12),

                  // ── Monthly Summary ─────────────────────────────────────
                  _MonthlySummaryCard(
                    income: _income,
                    expenses: _expenses,
                    net: net,
                    fmt: fmt,
                    isProjected: _isFuture,
                  ),
                  const SizedBox(height: 12),

                  // ── Recurring ───────────────────────────────────────────
                  if (_recurring.isNotEmpty) ...[
                    _RecurringOverviewCard(recurring: _recurring, fmt: fmt),
                    const SizedBox(height: 12),
                  ],

                  // ── Budget Overview ─────────────────────────────────────
                  if (_budgets.isNotEmpty) ...[
                    _BudgetOverviewCard(
                        budgets: _budgets,
                        spent: _categorySpend,
                        fmt: fmt),
                    const SizedBox(height: 12),
                  ],

                  // ── Savings Goals ───────────────────────────────────────
                  if (_goals.isNotEmpty) ...[
                    _SavingsOverviewCard(goals: _goals, fmt: fmt),
                    const SizedBox(height: 12),
                  ],

                  // ── Spending by Category ────────────────────────────────
                  if (_categorySpend.isNotEmpty) ...[
                    _SpendingCard(
                        categorySpend: _categorySpend, fmt: fmt),
                    const SizedBox(height: 12),
                  ],

                  // ── Recent Transactions ─────────────────────────────────
                  if (_recent.isNotEmpty)
                    _RecentCard(recent: _recent, fmt: fmt),
                ],
              ),
            ),
    );
  }
}

// ── Net Worth Card ────────────────────────────────────────────────────────────

class _NetWorthCard extends StatelessWidget {
  final double netWorth, assets, debt;
  final NumberFormat fmt;
  const _NetWorthCard(
      {required this.netWorth,
      required this.assets,
      required this.debt,
      required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Net Worth',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(fmt.format(netWorth),
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: netWorth >= 0 ? Colors.green : Colors.red)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _NetItem('Assets', assets, Colors.green, fmt)),
            Expanded(
                child: _NetItem('Debt', debt, Colors.red, fmt)),
          ]),
        ]),
      ),
    );
  }
}

class _NetItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final NumberFormat fmt;
  const _NetItem(this.label, this.value, this.color, this.fmt);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(fmt.format(value),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 15)),
        ],
      );
}

// ── Monthly Summary Card ──────────────────────────────────────────────────────

class _MonthlySummaryCard extends StatelessWidget {
  final double income, expenses, net;
  final NumberFormat fmt;
  final bool isProjected;
  const _MonthlySummaryCard(
      {required this.income,
      required this.expenses,
      required this.net,
      required this.fmt,
      this.isProjected = false});

  @override
  Widget build(BuildContext context) {
    final spentRatio =
        income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('This Month',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (isProjected)
            const Text('Based on your recurring transactions',
                style: TextStyle(fontSize: 11, color: Colors.orange)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatChip('Income', income, Colors.green, fmt),
              _StatChip('Spent', expenses, Colors.red, fmt),
              _StatChip(
                  'Net', net, net >= 0 ? Colors.blue : Colors.orange, fmt),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: spentRatio,
              minHeight: 10,
              backgroundColor: Colors.green.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(
                  expenses > income ? Colors.red : Colors.green),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            income > 0
                ? '${(spentRatio * 100).toStringAsFixed(0)}% of income spent'
                : 'No income recorded',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final NumberFormat fmt;
  const _StatChip(this.label, this.value, this.color, this.fmt);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(fmt.format(value),
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      ]);
}

// ── Recurring Overview Card ───────────────────────────────────────────────────

class _RecurringOverviewCard extends StatelessWidget {
  final List<RecurringTransaction> recurring;
  final NumberFormat fmt;
  const _RecurringOverviewCard(
      {required this.recurring, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = recurring
        .where((r) => r.isActive)
        .toList()
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    final totalMonthlyExpense = recurring
        .where((r) => r.isActive && r.type == 'expense')
        .fold(0.0, (s, r) => s + r.amount);
    final totalMonthlyIncome = recurring
        .where((r) => r.isActive && r.type == 'income')
        .fold(0.0, (s, r) => s + r.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recurring',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(children: [
              const Icon(Icons.arrow_downward, size: 12, color: Colors.green),
              Text(fmt.format(totalMonthlyIncome),
                  style: const TextStyle(fontSize: 11, color: Colors.green)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_upward, size: 12, color: Colors.red),
              Text(fmt.format(totalMonthlyExpense),
                  style: const TextStyle(fontSize: 11, color: Colors.red)),
            ]),
          ]),
          const SizedBox(height: 10),
          ...upcoming.take(4).map((r) {
            final due = DateTime(r.nextDueDate.year,
                r.nextDueDate.month, r.nextDueDate.day);
            final daysUntil = due.difference(today).inDays;
            final isDue = daysUntil <= 0;
            final isSoon = daysUntil <= 3 && daysUntil > 0;
            final isIncome = r.type == 'income';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: (isIncome ? Colors.green : Colors.red)
                      .withValues(alpha: 0.12),
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 12,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.category,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(
                        r.frequency[0].toUpperCase() +
                            r.frequency.substring(1),
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt.format(r.amount),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isIncome ? Colors.green : Colors.red)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isDue
                            ? Colors.red.withValues(alpha: 0.1)
                            : isSoon
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isDue
                            ? 'Due today'
                            : isSoon
                                ? 'In $daysUntil days'
                                : DateFormat('MMM d').format(r.nextDueDate),
                        style: TextStyle(
                            fontSize: 10,
                            color: isDue
                                ? Colors.red
                                : isSoon
                                    ? Colors.orange
                                    : Colors.grey),
                      ),
                    ),
                  ],
                ),
              ]),
            );
          }),
          if (upcoming.length > 4)
            Text('+ ${upcoming.length - 4} more',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

// ── Budget Overview Card ──────────────────────────────────────────────────────

class _BudgetOverviewCard extends StatelessWidget {
  final List<Budget> budgets;
  final Map<String, double> spent;
  final NumberFormat fmt;
  const _BudgetOverviewCard(
      {required this.budgets, required this.spent, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final overCount = budgets.where((b) => (spent[b.category] ?? 0) > b.limit).length;
    final underCount = budgets.length - overCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Budget Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(children: [
              if (overCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('$overCount over',
                      style: const TextStyle(color: Colors.red, fontSize: 11)),
                ),
                const SizedBox(width: 6),
              ],
              if (underCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('$underCount on track',
                      style: const TextStyle(color: Colors.green, fontSize: 11)),
                ),
            ]),
          ]),
          const SizedBox(height: 12),
          ...budgets.take(4).map((b) {
            final s = spent[b.category] ?? 0;
            final ratio = (s / b.limit).clamp(0.0, 1.0);
            final over = s > b.limit;
            final color = over
                ? Colors.red
                : ratio > 0.8
                    ? Colors.orange
                    : Colors.green;
            final diff = (b.limit - s).abs();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(b.category,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Row(children: [
                      Icon(
                        over ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: over ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        over
                            ? '${fmt.format(diff)} over'
                            : '${fmt.format(diff)} left',
                        style: TextStyle(
                            fontSize: 11,
                            color: over ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 4),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${fmt.format(s)} spent',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('of ${fmt.format(b.limit)} budget',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ]),
                ],
              ),
            );
          }),
          if (budgets.length > 4)
            Text('+ ${budgets.length - 4} more budgets',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

// ── Savings Overview Card ─────────────────────────────────────────────────────

class _SavingsOverviewCard extends StatelessWidget {
  final List<SavingsGoal> goals;
  final NumberFormat fmt;
  const _SavingsOverviewCard(
      {required this.goals, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Savings Goals',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...goals.take(3).map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(g.name,
                                style: const TextStyle(fontSize: 12)),
                            Text(
                                '${(g.progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold)),
                          ]),
                      const SizedBox(height: 3),
                      LinearProgressIndicator(
                        value: g.progress,
                        color: Colors.blue,
                        backgroundColor:
                            Colors.blue.withValues(alpha: 0.15),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      Text(
                          '${fmt.format(g.saved)} of ${fmt.format(g.target)}',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                    ]),
              )),
          if (goals.length > 3)
            Text('+ ${goals.length - 3} more',
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

// ── Spending by Category Card ─────────────────────────────────────────────────

class _SpendingCard extends StatelessWidget {
  final Map<String, double> categorySpend;
  final NumberFormat fmt;
  const _SpendingCard(
      {required this.categorySpend, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final sorted = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total =
        categorySpend.values.fold(0.0, (s, v) => s + v);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Spending by Category',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...sorted.take(5).map((e) {
            final ratio =
                total > 0 ? (e.value / total).clamp(0.0, 1.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: Text(e.key,
                      style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  flex: 5,
                  child: LinearProgressIndicator(
                    value: ratio,
                    color: Colors.indigo,
                    backgroundColor:
                        Colors.indigo.withValues(alpha: 0.1),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(fmt.format(e.value),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

// ── Recent Transactions Card ──────────────────────────────────────────────────

class _RecentCard extends StatelessWidget {
  final List<model.Transaction> recent;
  final NumberFormat fmt;
  const _RecentCard({required this.recent, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recent Transactions',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ...recent.map((t) {
            final isIncome = t.type == 'income';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: (isIncome ? Colors.green : Colors.red)
                    .withValues(alpha: 0.15),
                child: Icon(
                  isIncome
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 14,
                  color: isIncome ? Colors.green : Colors.red,
                ),
              ),
              title: Text(t.category,
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                  DateFormat('MMM d').format(t.date),
                  style: const TextStyle(fontSize: 11)),
              trailing: Text(fmt.format(t.amount),
                  style: TextStyle(
                      color: isIncome ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            );
          }),
        ]),
      ),
    );
  }
}



