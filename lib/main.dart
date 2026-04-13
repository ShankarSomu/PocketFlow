import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/savings_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/recurring_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/transactions_screen.dart';
import 'services/recurring_scheduler.dart';
import 'services/auth_service.dart';
import 'services/app_logger.dart';

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

class PocketFlowApp extends StatelessWidget {
  const PocketFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketFlow',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const _RootNav(),
    );
  }

  ThemeData _buildTheme() {
    const seed = Color(0xFF6C63FF); // vibrant indigo-purple
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
        primary: seed,
        secondary: const Color(0xFF03DAC6),
        tertiary: const Color(0xFFFF6584),
      ),
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1A2E),
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
      ),
      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black26,
        indicatorColor: seed.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF6C63FF), size: 26);
          }
          return const IconThemeData(color: Color(0xFF9E9E9E), size: 24);
        }),
      ),
      // Scaffold
      scaffoldBackgroundColor: const Color(0xFFF8F9FE),
      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F0F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
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
  static const _screens = [
    HomeScreen(),
    AccountsScreen(),
    BudgetScreen(),
    ChatScreen(),
    SavingsScreen(),
    RecurringScreen(),
    TransactionsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onTap: (i) {
          final screens = ['Home','Accounts','Budget','Chat','Savings','Recurring','Transactions','Profile'];
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
    const activeColor = Color(0xFF6C63FF);
    const inactiveColor = Color(0xFF9E9E9E);

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
      _NavItem(Icons.person_outline_rounded,
          Icons.person_rounded, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
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
                                    Color(0xFF6C63FF),
                                    Color(0xFF9C63FF)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF8B83FF),
                                    Color(0xFFB083FF)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF)
                                  .withValues(alpha: 0.4),
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

              // Map nav index to screen index
              // slots: 0,1,2,[3=chat],4,5,6
              // screens: 0=Home,1=Accounts,2=Budget,3=Chat,4=Savings,5=Recurring,6=Profile
              final si = i <= 2 ? i : i; // direct 1:1 since null slot is index 3
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

