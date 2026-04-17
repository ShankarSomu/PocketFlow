import '../../services/time_filter.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../models/account.dart';
import '../../models/budget.dart';
import '../../models/transaction.dart' as model;
import '../../services/auth_service.dart';
import '../../services/refresh_notifier.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import 'accounts_screen.dart';
import 'profile_screen.dart';
import 'savings_screen.dart';
import 'settings_screen.dart';
import 'shared.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _carouselController = PageController();
    _carousel2Controller = PageController();
    _load();
    appRefresh.addListener(_load);
    appTimeFilter.addListener(_load);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    appTimeFilter.removeListener(_load);
    _carouselController.dispose();
    _carousel2Controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  bool _loading = true;
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
  late final PageController _carouselController;
  int _carouselPage = 0;
  late final PageController _carousel2Controller;
  int _carousel2Page = 0;
  final ScrollController _scrollController = ScrollController();
  int _budgetAnimKey = 0;

  Future<void> _load() async {
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
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _pctChange(double current, double previous) {
    if (previous == 0) return current > 0 ? '+100%' : '—';
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
        content: Text('Notifications are coming soon — stay tuned!'),
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
                ? Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : Column(
                children: [
                  // ── Fixed header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: _buildHeader(),
                  ),
                  const SizedBox(height: 8),
                  // ── Scrollable body ──
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
              child: CalendarFab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel(NumberFormat fmt) {
    final pages = [
      _buildStatsRow(fmt),
      _buildAccountsOverview(fmt),
      _buildSmartInsights(),
    ];
    final labels = ['Overview', 'Accounts', 'Insights'];

    return ClipRect(
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            PageView.builder(
              controller: _carouselController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _carouselPage = i),
              itemBuilder: (context, index) => pages[index],
            ),
            // Left arrow (circular)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _CarouselArrow(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _carouselController.animateToPage(
                    (_carouselPage - 1 + pages.length) % pages.length,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
            // Right arrow (circular)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _CarouselArrow(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _carouselController.animateToPage(
                    (_carouselPage + 1) % pages.length,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
            // Page label + dots (top-right, compact)
            Positioned(
              top: 0,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      labels[_carouselPage],
                      key: ValueKey(_carouselPage),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...List.generate(pages.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 3),
                    width: i == _carouselPage ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i == _carouselPage ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = AuthService.currentUser;
    final firstName = user?.displayName?.split(' ').first;
    final userName = firstName ?? 'there';
    final photoUrl = user?.photoUrl;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar → taps to Profile
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.12),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onSecondary, size: 22)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        // Greeting + name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _greeting,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                userName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        // Time filter pill
        AnimatedBuilder(
          animation: appTimeFilter,
          builder: (ctx, _) => GestureDetector(
            onTap: () => showTimeFilterSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    appTimeFilter.current.shortLabel,
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 15),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Notifications
        GestureDetector(
          onTap: _showNotifications,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: AppTheme.cardShadow,
            ),
            child: Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 20),
          ),
        ),
        const SizedBox(width: 8),
        // Settings
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: AppTheme.cardShadow,
            ),
            child: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(NumberFormat fmt) {
    final incomeChg = _pctChange(_income, _prevIncome);
    final expChg = _pctChange(_expenses, _prevExpenses);
    final prevSavings = _prevIncome <= 0 ? 0.0 : ((_prevIncome - _prevExpenses) / _prevIncome).clamp(0.0, 1.0);
    final savingsDiff = ((_savingsRate - prevSavings) * 100);
    final savingsChg = '${savingsDiff >= 0 ? '+' : ''}${savingsDiff.toStringAsFixed(1)}pp';
    final netBalanceChg = _totalBalance >= 0 ? 'Total assets' : 'Net negative';
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMiniStat(
              'Net Balance', fmt.format(_totalBalance), netBalanceChg, ThemeService.instance.primaryColor,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AccountsScreen())),
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildMiniStat(
              'Savings Rate', '${(_savingsRate * 100).toStringAsFixed(0)}%', savingsChg, ThemeService.instance.primaryColor,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SavingsScreen())),
            )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMiniStat(
              'Income', fmt.format(_income), incomeChg, ThemeService.instance.primaryColor,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const TransactionsScreen(initialFilterType: 'income'))),
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildMiniStat(
              'Expenses', fmt.format(_expenses), expChg, AppTheme.error,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const TransactionsScreen(initialFilterType: 'expense'))),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStat(String title, String value, String change, Color accent, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: ThemeService.instance.cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: ThemeService.instance.primaryShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.trending_up, color: accent, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 3),
            Text(change, style: TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ),
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
                    gradient: LinearGradient(colors: [ThemeService.instance.primaryColor, ThemeService.instance.primaryDark]),
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(colors: [ThemeService.instance.primaryColor.withOpacity(0.28), ThemeService.instance.primaryColor.withOpacity(0.0)]),
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

  // ── Second horizontal carousel: Budget / Trend / Categories ──────────────

  Widget _buildSecondCarousel() {
    final pages = [
      _buildBudgetDonutPage(),
      _buildCategoryBarsPage(),
    ];
    final labels = ['Spending', 'Budgets'];

    return ClipRect(
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            PageView.builder(
              controller: _carousel2Controller,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _carousel2Page = i),
              itemBuilder: (context, index) => pages[index],
            ),
            // Left arrow (circular)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _CarouselArrow(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _carousel2Controller.animateToPage(
                    (_carousel2Page - 1 + pages.length) % pages.length,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
            // Right arrow (circular)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _CarouselArrow(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _carousel2Controller.animateToPage(
                    (_carousel2Page + 1) % pages.length,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
            // Page label + dots (top-right, compact)
            Positioned(
              top: 0,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      labels[_carousel2Page],
                      key: ValueKey(_carousel2Page),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...List.generate(pages.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 3),
                    width: i == _carousel2Page ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: i == _carousel2Page ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetDonutPage() {
    return _InteractiveDonut(
      key: ValueKey(_budgetAnimKey),
      categorySpend: _categorySpend,
    );
  }

  Widget _buildCategoryBarsPage() {
    return _BudgetProgressPage(
      budgets: _budgets,
      categorySpend: _categorySpend,
    );
  }

  Widget _buildRecentTransactions(NumberFormat fmt) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const TransactionsScreen())),
                  child: Text('See All',
                      style: TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          if (_recentTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text('No transactions yet',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 13))),
            )
          else
            ...List.generate(_recentTransactions.length, (i) {
              final t = _recentTransactions[i];
              final isIncome = t.type == 'income';
              final color = _HomeTransactionItem._color(t.category, isIncome);
              final icon = _HomeTransactionItem._icon(t.category, isIncome);
              final account = _accounts.where((a) => a.id == t.accountId).firstOrNull;
              final timeStr = DateFormat('d MMM, h:mm a').format(t.date);
              final subtitle = account != null ? '${account.name} • $timeStr' : timeStr;

              return Column(
                children: [
                  InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Text(t.category,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.onSurface)),
                                    const SizedBox(height: 3),
                                    Text(subtitle,
                                        style: TextStyle(
                                            fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${isIncome ? '+' : '−'}${fmt.format(t.amount.abs())}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isIncome ? const Color(0xFF059669) : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          if (t.note != null && t.note!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 56),
                              child: Text(
                                t.note!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (i < _recentTransactions.length - 1)
                    Divider(height: 1, indent: 70, endIndent: 16, color: Theme.of(context).colorScheme.outlineVariant),
                ],
              );
            }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  static IconData _accountTypeIcon(String type) => switch (type) {
    'checking' => Icons.account_balance_rounded,
    'savings'  => Icons.savings_rounded,
    'credit'   => Icons.credit_card_rounded,
    'cash'     => Icons.payments_rounded,
    _          => Icons.account_balance_wallet_rounded,
  };

  static Color _accountTypeColor(String type) => switch (type) {
    'checking' => Color(0xFF3B82F6),
    'savings'  => Color(0xFF10B981),
    'credit'   => Color(0xFFEF4444),
    'cash'     => Color(0xFFF59E0B),
    _          => Color(0xFF8B5CF6),
  };

  Widget _buildAccountsOverview(NumberFormat fmt) {
    return FigmaPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accounts',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Expanded(
            child: _accounts.isEmpty
                ? Center(
                    child: Text('No accounts yet',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))))
                : ListView.separated(
                    physics: const ClampingScrollPhysics(),
                    itemCount: _accounts.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
                    itemBuilder: (_, i) {
                      final account = _accounts[i];
                      final bal = _accountBalances[account.id] ?? 0.0;
                      final color = _accountTypeColor(account.type);
                      final icon = _accountTypeIcon(account.type);
                      final typeLabel = account.type[0].toUpperCase() +
                          account.type.substring(1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(account.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.onSurface),
                                      overflow: TextOverflow.ellipsis),
                                  Text(typeLabel,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                                ],
                              ),
                            ),
                            Text(fmt.format(bal),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  double _categoryBalance(Account account) {
    return _accountBalances[account.id] ?? 0.0;
  }

  List<Map<String, dynamic>> _generateInsights() {
    final list = <Map<String, dynamic>>[];

    // Top spending category
    if (_categorySpend.isNotEmpty) {
      final top = _categorySpend.entries.reduce((a, b) => a.value > b.value ? a : b);
      final pct = _expenses > 0 ? (top.value / _expenses * 100).round() : 0;
      list.add({
        'icon': Icons.pie_chart_rounded,
        'color': AppTheme.warning,
        'message': '${_titleCase(top.key)} is $pct% of your expenses this month.',
        'cta': 'Details',
        'route': 'expense',
      });
    }

    // Budget exceeded
    if (list.length < 2) {
      for (final b in _budgets) {
        final spent = _categorySpend[b.category] ?? 0;
        if (spent > b.limit) {
          final over = ((spent - b.limit) / b.limit * 100).round();
          list.add({
            'icon': Icons.warning_amber_rounded,
            'color': AppTheme.error,
            'message': '${_titleCase(b.category)} budget exceeded by $over%.',
            'cta': 'Review',
            'route': 'expense',
          });
          break;
        }
      }
    }

    // Savings insight
    if (list.length < 2 && _income > 0) {
      final sz = (_savingsRate * 100).round();
      final good = _savingsRate >= 0.2;
      list.add({
        'icon': Icons.savings_rounded,
        'color': good ? AppTheme.emerald : ThemeService.instance.primaryColor,
        'message': good
            ? 'Great! You\'re saving $sz% of income this month.'
            : 'Savings at $sz%. Aim for 20% to build a safety net.',
        'cta': 'Goals',
        'route': 'savings',
      });
    }

    if (list.isEmpty) {
      list.add({
        'icon': Icons.lightbulb_rounded,
        'color': ThemeService.instance.primaryColor,
        'message': 'Add transactions to unlock personalized insights.',
        'cta': 'Start',
        'route': 'none',
      });
    }

    return list.take(2).toList();
  }

  Widget _buildSmartInsights() {
    final insights = _generateInsights();
    return FigmaPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 15),
              const SizedBox(width: 6),
              Text('Smart Insights', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 8),
          ...insights.map((insight) {
            final color = insight['color'] as Color;
            final route = insight['route'] as String? ?? 'none';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Icon(insight['icon'] as IconData, color: color, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(insight['message'] as String, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)))),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: color.withOpacity(0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (route == 'income' || route == 'expense') {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TransactionsScreen(initialFilterType: route)));
                      } else if (route == 'savings') {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const SavingsScreen()));
                      } else {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const TransactionsScreen()));
                      }
                    },
                    child: Text(insight['cta'] as String, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
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

// ── Interactive Spend by Category Donut ─────────────────────────────────────

class _InteractiveDonut extends StatefulWidget {
  final Map<String, double> categorySpend;
  const _InteractiveDonut({super.key, required this.categorySpend});

  @override
  State<_InteractiveDonut> createState() => _InteractiveDonutState();
}

class _InteractiveDonutState extends State<_InteractiveDonut>
    with SingleTickerProviderStateMixin {
  int? _selectedIdx;
  late AnimationController _controller;
  late Animation<double> _animation;

  static const _colors = [
    Color(0xFF10B981), Color(0xFF3B82F6), Color(0xFF6366F1),
    Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF8B5CF6),
    Color(0xFFEF4444), Color(0xFF0EA5E9),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _animation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(_InteractiveDonut old) {
    super.didUpdateWidget(old);
    if (old.categorySpend != widget.categorySpend) {
      _selectedIdx = null;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<MapEntry<String, double>> _buildItems() {
    final all = widget.categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (all.length <= 6) return all;
    final top5 = all.take(5).toList();
    final rest = all.skip(5).fold(0.0, (s, e) => s + e.value);
    return [...top5, MapEntry('Others', rest)];
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final total = items.fold(0.0, (s, e) => s + e.value);
    final fmtC = NumberFormat.compactCurrency(symbol: r'$');
    final fmtF = NumberFormat.currency(symbol: r'$', decimalDigits: 0);

    return FigmaPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Spend by Category',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_selectedIdx != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedIdx = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.close_rounded,
                        size: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.pie_chart_outline_rounded,
                      size: 40, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  Text('No expenses recorded',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
                ]),
              ),
            )
          else
            Expanded(
              child: Row(
                children: [
                  // ── Donut ──
                  SizedBox(
                    width: 155,
                    height: 155,
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (_, __) => CustomPaint(
                        painter: _InteractiveDonutPainter(
                          items: items,
                          colors: _colors,
                          selectedIdx: _selectedIdx,
                          progress: _animation.value,
                        ),
                        child: GestureDetector(
                          onTapDown: (_) =>
                              setState(() => _selectedIdx = null),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _selectedIdx == null
                                  ? Column(
                                      key: const ValueKey('total'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(fmtC.format(total),
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Theme.of(context).colorScheme.onSurface)),
                                        Text('expenses',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                                      ],
                                    )
                                  : Column(
                                      key: ValueKey('sel_$_selectedIdx'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          total > 0
                                              ? '${(items[_selectedIdx!].value / total * 100).toStringAsFixed(1)}%'
                                              : '0%',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: _colors[_selectedIdx! %
                                                  _colors.length]),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            _titleCase(items[_selectedIdx!].key),
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                fontWeight: FontWeight.w600),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          fmtF.format(
                                              items[_selectedIdx!].value),
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ── Legend ──
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: items.asMap().entries.map((e) {
                        final color = _colors[e.key % _colors.length];
                        final isSelected = _selectedIdx == e.key;
                        final isOtherSel =
                            _selectedIdx != null && !isSelected;
                        final pct = total > 0
                            ? (e.value.value / total * 100)
                                .toStringAsFixed(0)
                            : '0';
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _selectedIdx = isSelected ? null : e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 7),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: color.withValues(alpha: 0.3))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: isSelected ? 10 : 8,
                                  height: isSelected ? 10 : 8,
                                  decoration: BoxDecoration(
                                    color: isOtherSel
                                        ? color.withValues(alpha: 0.35)
                                        : color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _titleCase(e.value.key),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isOtherSel
                                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4)
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('$pct%',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isOtherSel
                                            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.3)
                                            : color)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InteractiveDonutPainter extends CustomPainter {
  final List<MapEntry<String, double>> items;
  final List<Color> colors;
  final int? selectedIdx;
  final double progress;

  static const double _strokeWidth = 20.0;
  static const double _expansion = 8.0;
  static const double _gap = 0.03;

  _InteractiveDonutPainter({
    required this.items,
    required this.colors,
    required this.selectedIdx,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold(0.0, (s, e) => s + e.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius =
        (size.shortestSide / 2) - _strokeWidth / 2 - _expansion - 2;

    // Track ring
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth,
    );

    double currentAngle = -pi / 2;
    for (int i = 0; i < items.length; i++) {
      final fraction = items[i].value / total;
      final sweep = 2 * pi * fraction * progress;
      if (sweep <= 0) continue;

      final isSelected = selectedIdx == i;
      final isOtherSel = selectedIdx != null && !isSelected;
      final color = colors[i % colors.length];
      final midAngle = currentAngle + sweep / 2;

      final offsetDist = isSelected ? _expansion * 0.7 : 0.0;
      final drawCenter = center +
          Offset(cos(midAngle) * offsetDist, sin(midAngle) * offsetDist);

      if (isSelected) {
        canvas.drawArc(
          Rect.fromCircle(center: drawCenter, radius: baseRadius),
          currentAngle + _gap / 2,
          (sweep - _gap).clamp(0.01, sweep),
          false,
          Paint()
            ..color = color.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _strokeWidth + 8
            ..strokeCap = StrokeCap.round,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: drawCenter, radius: baseRadius),
        currentAngle + _gap / 2,
        (sweep - _gap).clamp(0.01, sweep),
        false,
        Paint()
          ..color = isOtherSel ? color.withValues(alpha: 0.3) : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      currentAngle += 2 * pi * fraction * progress;
    }
  }

  @override
  bool shouldRepaint(_InteractiveDonutPainter old) =>
      old.selectedIdx != selectedIdx ||
      old.progress != progress ||
      old.items != items;
}

// ── Budget Progress Tracker ───────────────────────────────────────────────────

class _BudgetProgressPage extends StatelessWidget {
  final List<Budget> budgets;
  final Map<String, double> categorySpend;

  const _BudgetProgressPage(
      {required this.budgets, required this.categorySpend});

  Color _barColor(double pct) {
    if (pct > 1.0) return const Color(0xFFEF4444);
    if (pct >= 0.9) return const Color(0xFFFF6B35);
    if (pct >= 0.7) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final items = budgets
        .map((b) => (budget: b, spent: categorySpend[b.category] ?? 0.0))
        .toList()
      ..sort((a, b) =>
          (b.spent / (b.budget.limit > 0 ? b.budget.limit : 1))
              .compareTo(a.spent / (a.budget.limit > 0 ? a.budget.limit : 1)));

    final hasOver = items.any((e) => e.spent > e.budget.limit);

    return FigmaPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Budget Progress',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface)),
              const Spacer(),
              if (hasOver)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Over Budget!',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444))),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bar_chart_rounded, size: 40,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  Text('No budgets set',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
                ]),
              ),
            )
          else
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: items.take(5).map((e) {
                  final rawPct = e.budget.limit > 0
                      ? e.spent / e.budget.limit
                      : (e.spent > 0 ? 1.0 : 0.0);
                  final barPct = rawPct.clamp(0.0, 1.0);
                  final color = _barColor(rawPct);
                  final isOver = rawPct > 1.0;
                  final remaining = e.budget.limit - e.spent;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isOver)
                            Padding(
                              padding: EdgeInsets.only(right: 3),
                              child: Icon(Icons.warning_amber_rounded,
                                  size: 11, color: Color(0xFFEF4444)),
                            ),
                          Expanded(
                            child: Text(
                              e.budget.category.isNotEmpty
                                  ? e.budget.category[0].toUpperCase() + e.budget.category.substring(1)
                                  : e.budget.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isOver
                                    ? const Color(0xFFEF4444)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${fmt.format(e.spent)} / ${fmt.format(e.budget.limit)}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: barPct),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => Stack(
                          children: [
                            Container(
                              height: 9,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                height: 9,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: isOver
                                      ? [
                                          BoxShadow(
                                            color:
                                                color.withValues(alpha: 0.45),
                                            blurRadius: 6,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isOver
                            ? '⚠ Overspent by ${fmt.format(-remaining)}'
                            : remaining <= 0
                                ? 'Budget fully used'
                                : '${fmt.format(remaining)} remaining · ${(rawPct * 100).toStringAsFixed(0)}% used',
                        style: TextStyle(
                            fontSize: 9,
                            color: isOver
                                ? const Color(0xFFEF4444)
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Transaction icon / color helpers (mirrors transactions_screen.dart) ───────

class _HomeTransactionItem {
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
}

// ── Transparent carousel arrow FAB ──────────────────────────────────────────

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CarouselArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 26),
      ),
    );
  }
}