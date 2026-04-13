import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/transaction.dart' as model;
import '../models/savings_goal.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../services/refresh_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _income = 0, _expenses = 0;
  double _totalAssets = 0, _totalDebt = 0;
  double _savingsRate = 0;
  Map<String, double> _categorySpend = {};
  List<model.Transaction> _recent = [];
  List<SavingsGoal> _goals = [];
  List<Budget> _budgets = [];
  List<RecurringTransaction> _recurring = [];
  List<Map<String, dynamic>> _accountsQuickView = [];
  int _activeAccountsCount = 0;
  int _goalsOnTrack = 0;
  double _budgetCompliance = 0;
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
      final accountsQuick = <Map<String, dynamic>>[];
      for (final a in accounts) {
        final bal = await AppDatabase.accountBalance(a.id!, a);
        if (a.type == 'credit') {
          debt += bal;
        } else {
          assets += bal;
        }
        accountsQuick.add({
          'name': a.name,
          'balance': bal,
          'type': a.type,
        });
      }

      // Calculate savings rate
      final savingsRate = income > 0 ? ((income - expenses) / income * 100).clamp(0.0, 100.0) : 0.0;

      // Calculate budget compliance
      final budgetsWithLimit = budgets.where((b) => b.limit > 0).toList();
      int onTrackCount = 0;
      for (final b in budgetsWithLimit) {
        final spent = cats[b.category] ?? 0;
        if (spent <= b.limit) onTrackCount++;
      }
      final budgetCompliance = budgetsWithLimit.isNotEmpty
          ? (onTrackCount / budgetsWithLimit.length * 100)
          : 0.0;

      // Calculate goals on track
      final goalsOnTrack = goals.where((g) => g.progress >= 0.5).length;

      if (!mounted) return;
      setState(() {
        _income = income;
        _expenses = expenses;
        _categorySpend = cats;
        _recent = recent.take(5).toList();
        _goals = goals;
        _budgets = budgetsWithLimit;
        _recurring = recurringAll.where((r) => r.isActive).toList();
        _totalAssets = assets;
        _totalDebt = debt;
        _savingsRate = savingsRate;
        _accountsQuickView = accountsQuick.take(3).toList();
        _activeAccountsCount = accounts.length;
        _goalsOnTrack = goalsOnTrack;
        _budgetCompliance = budgetCompliance;
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
                      padding: const EdgeInsets.all(24),
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
                                      'Overview',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w300,
                                        letterSpacing: -1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Your financial snapshot',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.emerald.withOpacity(0.2), AppTheme.blue.withOpacity(0.2)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, size: 16, color: AppTheme.emerald),
                                    const SizedBox(width: 6),
                                    Text(
                                      'All systems healthy',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.emerald,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Month Selector
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
                              Column(
                                children: [
                                  Text(
                                    DateFormat('MMMM yyyy').format(_month),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (_isFuture)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                      ),
                                      child: const Text(
                                        'PROJECTED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else if (isCurrentMonth)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        'CURRENT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.emerald,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                                  onPressed: _nextMonth,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Scrollable Content
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          children: [
                            _NetWorthCard(
                              netWorth: netWorth,
                              assets: _totalAssets,
                              debt: _totalDebt,
                              fmt: fmt,
                            ),
                            const SizedBox(height: 16),
                            _MonthlySummaryCard(
                              income: _income,
                              expenses: _expenses,
                              net: net,
                              fmt: fmt,
                              isProjected: _isFuture,
                            ),
                            const SizedBox(height: 16),
                            _StatsGrid(
                              savingsRate: _savingsRate,
                              budgetCompliance: _budgetCompliance,
                              goalsOnTrack: _goalsOnTrack,
                              totalGoals: _goals.length,
                              activeAccounts: _activeAccountsCount,
                            ),
                            const SizedBox(height: 16),
                            if (_recurring.isNotEmpty) ...[
                              _RecurringOverviewCard(recurring: _recurring, fmt: fmt),
                              const SizedBox(height: 16),
                            ],
                            if (_budgets.isNotEmpty) ...[
                              _BudgetOverviewCard(
                                  budgets: _budgets,
                                  spent: _categorySpend,
                                  fmt: fmt),
                              const SizedBox(height: 16),
                            ],
                            if (_goals.isNotEmpty) ...[
                              _SavingsOverviewCard(goals: _goals, fmt: fmt),
                              const SizedBox(height: 16),
                            ],
                            if (_categorySpend.isNotEmpty) ...[
                              _SpendingCard(
                                  categorySpend: _categorySpend, fmt: fmt),
                              const SizedBox(height: 16),
                            ],
                            _ThreeColumnLayout(
                              accountsQuickView: _accountsQuickView,
                              recent: _recent,
                              fmt: fmt,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
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
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.emeraldBlueGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emerald.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
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
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Net Worth',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      Icon(Icons.visibility_outlined, color: Colors.white70, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fmt.format(netWorth),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.trending_up, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Assets',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                fmt.format(assets),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.trending_down, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Debt',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                fmt.format(debt),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
    final spentRatio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
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
        padding: const EdgeInsets.all(24),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate900,
                  ),
                ),
                if (isProjected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Projected',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Income',
                    value: income,
                    icon: Icons.arrow_downward_rounded,
                    gradient: AppTheme.emeraldGradient,
                    fmt: fmt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Expenses',
                    value: expenses,
                    icon: Icons.arrow_upward_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    ),
                    fmt: fmt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Net',
                    value: net,
                    icon: net >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    gradient: net >= 0 ? AppTheme.blueGradient : const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    fmt: fmt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: spentRatio,
                minHeight: 12,
                backgroundColor: AppTheme.emerald.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  expenses > income ? AppTheme.error : AppTheme.emerald,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              income > 0
                  ? '${(spentRatio * 100).toStringAsFixed(0)}% of income spent'
                  : 'No income recorded',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.slate500,
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
  final IconData icon;
  final Gradient gradient;
  final NumberFormat fmt;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fmt.format(value),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
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

// ── Stats Grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final double savingsRate;
  final double budgetCompliance;
  final int goalsOnTrack;
  final int totalGoals;
  final int activeAccounts;

  const _StatsGrid({
    required this.savingsRate,
    required this.budgetCompliance,
    required this.goalsOnTrack,
    required this.totalGoals,
    required this.activeAccounts,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
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
      child: Row(
        children: [
          Expanded(
            child: _StatGridCard(
              label: 'Savings Rate',
              value: '${savingsRate.toStringAsFixed(0)}%',
              icon: Icons.savings_outlined,
              gradient: AppTheme.emeraldGradient,
              trend: savingsRate >= 20 ? 'Good' : 'Low',
              trendUp: savingsRate >= 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatGridCard(
              label: 'Budget',
              value: '${budgetCompliance.toStringAsFixed(0)}%',
              icon: Icons.pie_chart_outline,
              gradient: AppTheme.blueGradient,
              trend: budgetCompliance >= 80 ? 'On Track' : 'Review',
              trendUp: budgetCompliance >= 80,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatGridCard(
              label: 'Goals',
              value: '$goalsOnTrack/$totalGoals',
              icon: Icons.flag_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              ),
              trend: totalGoals > 0 && goalsOnTrack == totalGoals ? 'All' : 'Active',
              trendUp: totalGoals > 0 && goalsOnTrack == totalGoals,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatGridCard(
              label: 'Accounts',
              value: '$activeAccounts',
              icon: Icons.account_balance_wallet_outlined,
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
              trend: 'Active',
              trendUp: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGridCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final String trend;
  final bool trendUp;

  const _StatGridCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.trend,
    required this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                trendUp ? Icons.trending_up : Icons.trending_down,
                size: 12,
                color: trendUp ? AppTheme.emerald : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 10,
                  color: trendUp ? AppTheme.emerald : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Three Column Layout ───────────────────────────────────────────────────────

class _ThreeColumnLayout extends StatelessWidget {
  final List<Map<String, dynamic>> accountsQuickView;
  final List<model.Transaction> recent;
  final NumberFormat fmt;

  const _ThreeColumnLayout({
    required this.accountsQuickView,
    required this.recent,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _AccountsQuickView(accounts: accountsQuickView, fmt: fmt),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _RecentTransactionsQuick(recent: recent, fmt: fmt),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActions(),
          ),
        ],
      ),
    );
  }
}

class _AccountsQuickView extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final NumberFormat fmt;

  const _AccountsQuickView({required this.accounts, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppTheme.blueGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Accounts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (accounts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No accounts',
                  style: TextStyle(color: AppTheme.slate400, fontSize: 12),
                ),
              ),
            )
          else
            ...accounts.map((a) {
              final type = a['type'] as String;
              final color = type == 'checking'
                  ? AppTheme.blue
                  : type == 'savings'
                      ? AppTheme.emerald
                      : type == 'credit'
                          ? AppTheme.error
                          : Colors.amber;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a['name'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.slate700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      fmt.format(a['balance']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: type == 'credit' ? AppTheme.error : AppTheme.slate900,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _RecentTransactionsQuick extends StatelessWidget {
  final List<model.Transaction> recent;
  final NumberFormat fmt;

  const _RecentTransactionsQuick({required this.recent, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppTheme.emeraldGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.receipt_long, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recent',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No transactions',
                  style: TextStyle(color: AppTheme.slate400, fontSize: 12),
                ),
              ),
            )
          else
            ...recent.take(5).map((t) {
              final isIncome = t.type == 'income';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (isIncome ? AppTheme.emerald : AppTheme.error).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 12,
                        color: isIncome ? AppTheme.emerald : AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.category,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.slate700,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            DateFormat('MMM d').format(t.date),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      fmt.format(t.amount),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isIncome ? AppTheme.emerald : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _QuickActionButton(
            label: 'Add Transaction',
            icon: Icons.add_circle_outline,
            gradient: AppTheme.emeraldGradient,
            onTap: () => Navigator.pushNamed(context, '/chat'),
          ),
          const SizedBox(height: 8),
          _QuickActionButton(
            label: 'Transfer',
            icon: Icons.swap_horiz,
            gradient: AppTheme.blueGradient,
            onTap: () => Navigator.pushNamed(context, '/accounts'),
          ),
          const SizedBox(height: 8),
          _QuickActionButton(
            label: 'Set Budget',
            icon: Icons.pie_chart,
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
            ),
            onTap: () => Navigator.pushNamed(context, '/budget'),
          ),
          const SizedBox(height: 8),
          _QuickActionButton(
            label: 'New Goal',
            icon: Icons.flag,
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            ),
            onTap: () => Navigator.pushNamed(context, '/savings'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



