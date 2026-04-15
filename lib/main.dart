import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/figma/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/figma/budget_screen.dart';
import 'screens/figma/savings_screen.dart';
import 'screens/figma/accounts_screen.dart';
import 'screens/figma/recurring_screen.dart';
import 'screens/figma/profile_screen.dart';
import 'screens/figma/transactions_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/recurring_scheduler.dart';
import 'services/auth_service.dart';
import 'services/app_logger.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await AppLogger.load();
  await AppLogger.init();
  await AuthService.init();
  AuthService.autoBackupIfDue();
  RecurringScheduler.processDue();
  runApp(const PocketFlowApp());
}

class PocketFlowApp extends StatefulWidget {
  const PocketFlowApp({super.key});

  @override
  State<PocketFlowApp> createState() => _PocketFlowAppState();
}

class _PocketFlowAppState extends State<PocketFlowApp> {
  bool _showWelcome = true;
  bool _loading = true;
  bool _isFirstTime = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;
    
    if (hasSeenWelcome) {
      // Returning user - show splash briefly
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _showWelcome = false;
          _loading = false;
        });
      }
    } else {
      // First time user - show full welcome
      if (mounted) {
        setState(() {
          _isFirstTime = true;
          _showWelcome = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _onGetStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    if (mounted) {
      setState(() => _showWelcome = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _loading
          ? Scaffold(
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF064E3B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 64, color: Colors.white),
                      SizedBox(height: 24),
                      CircularProgressIndicator(color: Colors.white),
                    ],
                  ),
                ),
              ),
            )
          : _showWelcome
              ? WelcomeScreen(onGetStarted: _onGetStarted, isFirstTime: _isFirstTime)
              : const _RootNav(),
    );
  }
}

class _RootNav extends StatefulWidget {
  const _RootNav();
  @override
  State<_RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<_RootNav> {
  int _index = 0;

  // Chat is index 3 — center of 7 items
  final _screens = const [
    HomeScreen(),
    AccountsScreen(),
    BudgetScreen(),
    ChatScreen(),
    SavingsScreen(),
    RecurringScreen(),
    TransactionsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onTap: (i) {
          final screens = ['Home','Accounts','Budget','Chat','Savings','Recurring','Transactions'];
          AppLogger.nav(i < screens.length ? screens[i] : 'Screen$i');
          setState(() => _index = i);
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const activeColor = AppTheme.indigo;
    const inactiveColor = AppTheme.slate400;

    final items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
      _NavItem(Icons.account_balance_wallet_outlined,
          Icons.account_balance_wallet_rounded, 'Accounts'),
      _NavItem(Icons.pie_chart_outline_rounded,
          Icons.pie_chart_rounded, 'Budget'),
      null, // centre FAB placeholder
      _NavItem(Icons.savings_outlined, Icons.savings_rounded, 'Savings'),
      _NavItem(Icons.repeat_rounded, Icons.repeat_rounded, 'Recurring'),
      _NavItem(Icons.receipt_long_outlined,
          Icons.receipt_long_rounded, 'Transactions'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: AppTheme.cardShadow,
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              if (items[i] == null) {
                // Centre AI Chat FAB
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(3),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: index == 3
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                    Color(0xFF3B82F6)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                    Color(0xFF3B82F6)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.indigo.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                );
              }

              final si = i <= 2 ? i : i;
              final isSelected = index == si;
              final item = items[i]!;

              return Expanded(
                child: Tooltip(
                  message: item.label,
                  child: InkWell(
                    onTap: () => onTap(si),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            key: ValueKey(isSelected),
                            color: isSelected ? activeColor : inactiveColor,
                            size: isSelected ? 26 : 24,
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 4 : 0,
                          height: isSelected ? 4 : 0,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: const BoxDecoration(
                            color: activeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

