import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../models/account.dart';
import '../../models/budget.dart';
import '../../models/transaction.dart' as model;
import '../../services/refresh_notifier.dart';
import '../../services/theme_service.dart';
import '../../services/time_filter.dart';
import '../../theme/app_color_scheme.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/feature_hint.dart';
import 'home/components/home_components.dart';
import 'shared.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    _scrollController.dispose();
    super.dispose();
  }
  bool _loading = true;
  String? _error;
  double _totalBalance = 0;
  double _income = 0;
  double _expenses = 0;
  double _prevIncome = 0;
  double _prevExpenses = 0;
  List<model.Transaction> _recentTransactions = [];
  List<Account> _accounts = [];
  final Map<int, double> _accountBalances = {};
  Map<String, double> _categorySpend = {};
  List<Budget> _budgets = [];
  bool _showBalance = true;
  final ScrollController _scrollController = ScrollController();
  int _budgetAnimKey = 0;

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final filter = appTimeFilter.current;
      final prevFrom = filter.prevFrom;
      final prevTo = filter.prevTo;
      final accounts = await AppDatabase.getAccounts();
      final income = await AppDatabase.rangeTotal('income', filter.from, filter.to);
      final expenses = await AppDatabase.rangeTotal('expense', filter.from, filter.to);
      final prevIncome = await AppDatabase.rangeTotal('income', prevFrom, prevTo);
      final prevExpenses = await AppDatabase.rangeTotal('expense', prevFrom, prevTo);
      final categorySpend = await AppDatabase.rangeExpenseByCategory(filter.from, filter.to);
      final budgets = await AppDatabase.getBudgets(filter.budgetMonth, filter.budgetYear);
      final transactions = await AppDatabase.getTransactions(from: filter.from, to: filter.to);

      double totalBalance = 0;
      final balances = <int, double>{};
      for (final account in accounts) {
        final balance = await AppDatabase.accountBalance(account.id!, account);
        balances[account.id!] = balance;
        if (account.type == 'credit') {
          totalBalance -= balance;
        } else {
          totalBalance += balance;
        }
      }

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _accountBalances.clear();
        _accountBalances.addAll(balances);
        _income = income;
        _expenses = expenses;
        _prevIncome = prevIncome;
        _prevExpenses = prevExpenses;
        _categorySpend = categorySpend;
        _budgets = budgets;
        _recentTransactions = transactions.take(5).toList();
        _totalBalance = totalBalance;
        _loading = false;
        _budgetAnimKey++; // re-animate donut on every data refresh
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _loading = false;
      });
    }
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _pctChange(double current, double previous) {
    if (previous == 0) return current > 0 ? '+100%' : '�';
    final pct = (current - previous) / previous * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  double get _savingsRate {
    if (_income <= 0) return 0;
    return ((_income - _expenses) / _income).clamp(0, 1);
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications are coming soon � stay tuned!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            _loading
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                : _error != null
                    ? ErrorStateWidget(
                        message: _error!,
                        onRetry: _load,
                      )
                    : Column(
                children: [
                  // -- Fixed header --
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: HomeHeader(onNotificationsTap: _showNotifications),
                  ),
                  const SizedBox(height: 8),
                  // -- Scrollable body --
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                        children: [
                          _buildCarousel(fmt),
                          const SizedBox(height: 10),
                          _buildSecondCarousel(),
                          const SizedBox(height: 10),
                          _buildRecentTransactions(fmt),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            const Positioned(
              bottom: 16,
              left: 16,
              child: FeatureHint(
                featureKey: FeatureHints.timeFilter,
                message: 'Tap to filter by time period',
                alignment: Alignment.bottomLeft,
                child: CalendarFab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel(NumberFormat fmt) {
    return SizedBox(
      height: 260,
      child: HomeStatsRow(
        totalBalance: _totalBalance,
        income: _income,
        expenses: _expenses,
        prevIncome: _prevIncome,
        prevExpenses: _prevExpenses,
        savingsRate: _savingsRate,
      ),
    );
  }

  Widget _buildSpendingChart() {
    final spots = [
      FlSpot(0, 3200),
      FlSpot(1, 3800),
      FlSpot(2, 4100),
      FlSpot(3, 3500),
      FlSpot(4, 3900),
      FlSpot(5, 4231),
    ];

    return FigmaPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              Text('Spending Trend', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
                        if (value.toInt() < 0 || value.toInt() >= labels.length) return const SizedBox.shrink();
                        return Text(labels[value.toInt()], style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 11));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).extension<AppColorScheme>()!.graphPositiveStart,
                        Theme.of(context).extension<AppColorScheme>()!.graphPositiveEnd,
                      ],
                    ),
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).extension<AppColorScheme>()!.graphPositiveStart.withOpacity(0.28),
                          Theme.of(context).extension<AppColorScheme>()!.graphPositiveStart.withOpacity(0.0),
                        ],
                      ),
                    ),
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondCarousel() {
    return SizedBox(
      height: 260,
      child: _buildBudgetDonutPage(),
    );
  }

  Widget _buildBudgetDonutPage() {
    return InteractiveDonut(
      key: ValueKey(_budgetAnimKey),
      categorySpend: _categorySpend,
    );
  }

  Widget _buildCategoryBarsPage() {
    return BudgetProgressPage(
      budgets: _budgets,
      categorySpend: _categorySpend,
    );
  }

  Widget _buildRecentTransactions(NumberFormat fmt) {
    return HomeRecentTransactions(
      transactions: _recentTransactions,
      accounts: _accounts,
    );
  }
}