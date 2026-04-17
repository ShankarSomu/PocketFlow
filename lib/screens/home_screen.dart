import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/color_extensions.dart';
import '../core/formatters.dart';
import '../db/database.dart';
import '../models/transaction.dart' as model;
import '../models/account.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/refresh_notifier.dart';
import '../theme/app_theme.dart';
import 'home/components/home_components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _totalBalance = 0;
  double _cashAvailable = 0;
  double _monthlyChange = 0;
  double _income = 0, _expenses = 0;
  Map<String, double> _categorySpend = {};
  List<model.Transaction> _recent = [];
  List<Account> _accounts = [];
  bool _loading = true;

  late final PageController _dashboardController;
  int _dashboardPage = 0;
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _dashboardController = PageController(viewportFraction: 1.0);
    _load();
    appRefresh.addListener(_load);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    _dashboardController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final accounts = await AppDatabase.getAccounts();
      final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
      final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
      final cats = await AppDatabase.monthlyExpenseByCategory(now.month, now.year);
      final recent = await AppDatabase.getTransactions(
        from: DateTime(now.year, now.month, 1),
        to: DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1)),
      );

      double totalBalance = 0;
      double cashAvailable = 0;
      for (final a in accounts) {
        final bal = await AppDatabase.accountBalance(a.id!, a);
        if (a.type == 'credit') {
          totalBalance -= bal;
        } else {
          totalBalance += bal;
          if (a.type == 'checking' || a.type == 'cash') {
            cashAvailable += bal;
          }
        }
      }

      final monthlyChange = income - expenses;

      if (!mounted) return;
      setState(() {
        _totalBalance = totalBalance;
        _cashAvailable = cashAvailable;
        _monthlyChange = monthlyChange;
        _income = income;
        _expenses = expenses;
        _categorySpend = cats;
        _recent = recent.take(5).toList();
        _accounts = accounts;
        _selectedCategoryIndex = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.indigo,
      ),
    );
  }

  void _onDashboardPageChanged(int page) {
    setState(() => _dashboardPage = page);
  }

  void _selectCategory(int index) {
    setState(() => _selectedCategoryIndex = index);
  }

  Widget _buildDashboardPager(NumberFormat fmt, double height) {
    return ClipRect(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _dashboardController,
                physics: const PageScrollPhysics(),
                onPageChanged: _onDashboardPageChanged,
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BalanceCard(
                          totalBalance: _totalBalance,
                          cashAvailable: _cashAvailable,
                          monthlyChange: _monthlyChange,
                          fmt: fmt,
                        ),
                        const SizedBox(height: 16),
                        QuickActions(onAction: _showComingSoon),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SpendingSnapshot(
                      income: _income,
                      expenses: _expenses,
                      categorySpend: _categorySpend,
                      fmt: fmt,
                      selectedIndex: _selectedCategoryIndex,
                      onCategorySelected: _selectCategory,
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BudgetCards(categorySpend: _categorySpend, fmt: fmt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildPageDots(count: 3, activeIndex: _dashboardPage),
          ],
        ),
      ),
    );
  }

  Widget _buildPageDots({required int count, required int activeIndex}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? context.colors.onPrimary : context.colors.onPrimary.faint,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final monthLabel = DateFormat('MMMM yyyy').format(now);
    final user = AuthService.currentUser;
    final userName = user?.displayName?.split(' ').first ?? 'there';
    final avatarUrl = user?.photoUrl;
    // Height for the carousel pager — tall enough to show richest page
    final pagerHeight = MediaQuery.of(context).size.height * 0.60;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary))
              : Column(
                  children: [
                    // ── Fixed Header (like Accounts / Profile screens) ──────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Row(
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap: () => _showComingSoon('Profile'),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: ThemeService.instance.cardGradient,
                                boxShadow: ThemeService.instance.primaryShadow,
                              ),
                              child: avatarUrl != null
                                  ? ClipOval(child: Image.network(avatarUrl, fit: BoxFit.cover))
                                  : Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Greeting + name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$greeting, $userName 👋',
                                  style: TextStyle(
                                    color: context.colors.onSurface.lighter,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.onPrimary,
                                      Theme.of(context).colorScheme.onPrimaryContainer,
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    'Dashboard',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Month badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.colors.onPrimary.veryFaint),
                            ),
                            child: Text(
                              monthLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Notification button
                          GestureDetector(
                            onTap: () => _showComingSoon('Notifications'),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: context.colors.onPrimary.veryFaint,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.notifications_none, color: Theme.of(context).colorScheme.onPrimary, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Scrollable Content ─────────────────────────────────────
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          children: [
                            _buildDashboardPager(fmt, pagerHeight),
                            const SizedBox(height: 16),
                            RecentTransactions(recent: _recent, fmt: fmt),
                            const SizedBox(height: 16),
                            AlertsInsights(accounts: _accounts, fmt: fmt),
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




