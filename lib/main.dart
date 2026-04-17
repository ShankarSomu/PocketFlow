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
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'core/app_dependencies.dart';
import 'widgets/error_boundary.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up global error handler
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.log(
      LogLevel.error,
      LogCategory.error,
      'Flutter Error',
      detail: details.exceptionAsString(),
    );
    if (details.stack != null) {
      AppLogger.log(
        LogLevel.error,
        LogCategory.error,
        'Stack Trace',
        detail: details.stack.toString(),
      );
    }
  };
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  await AppLogger.load();
  await AppLogger.init();
  await AuthService.init();
  await ThemeService.instance.init();
  AuthService.autoBackupIfDue();
  RecurringScheduler.processDue();
  runApp(const PocketFlowApp());
}

// Global nav-index notifier – updated by _RootNavState so the FAB in the
// MaterialApp builder can react even when Profile/Settings are pushed on top.
final _rootNavIndex = ValueNotifier<int>(0);
VoidCallback? _rootGoHome;

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
    return AppDependencies.wrapApp(
      ListenableBuilder(
        listenable: Listenable.merge([ThemeService.instance, _rootNavIndex]),
        builder: (context, _) {
          final ts = ThemeService.instance;
          // Reactive system UI style based on effective brightness
          final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
          final effectiveDark = ts.mode == AppThemeMode.dark ||
              (ts.mode == AppThemeMode.system && platformBrightness == Brightness.dark);
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: effectiveDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: effectiveDark ? Brightness.dark : Brightness.light,
          ));
          return MaterialApp(
          title: 'PocketFlow',
          debugShowCheckedModeBanner: false,
          theme: ts.buildLightTheme(),
          darkTheme: ts.buildDarkTheme(),
          themeMode: ts.flutterThemeMode,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            Widget result = MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaleFactor * ts.textSizeScale)),
              child: child!,
            );
            // Floating home button — shown above ALL routes (incl. Profile/Settings)
            final navIdx = _rootNavIndex.value;
            if (navIdx != 0) {
              result = Stack(
                children: [
                  result,
                  Positioned(
                    bottom: 140,
                    left: ts.leftHanded ? 16 : null,
                    right: ts.leftHanded ? null : 16,
                    child: SafeArea(
                      child: GestureDetector(
                        onTap: () => _rootGoHome?.call(),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(23),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.home_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return result;
          },
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
        },
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
  late final PageController _pageCtrl;
  int _index = 0;

  // Order: Home | Transactions | Recurring | Chat (FAB) | Savings | Budget | Accounts
  final _screens = const [
    HomeScreen(),
    TransactionsScreen(),
    RecurringScreen(),
    ChatScreen(),
    SavingsScreen(),
    BudgetScreen(),
    AccountsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 7 * 500);
    _rootGoHome = () => _goTo(0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    const names = ['Home','Transactions','Recurring','Chat','Savings','Budget','Accounts'];
    AppLogger.nav(names[i]);
    final currentPage = _pageCtrl.page?.round() ?? (_screens.length * 500);
    final currentSlot = currentPage % _screens.length;
    int diff = (i - currentSlot) % _screens.length;
    if (diff > _screens.length ~/ 2) diff -= _screens.length;
    setState(() => _index = i);
    _rootNavIndex.value = i;
    if (diff == 0) return;
    _pageCtrl.animateToPage(
      currentPage + diff,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            onPageChanged: (i) {
              const names = ['Home','Transactions','Recurring','Chat','Savings','Budget','Accounts'];
              final idx = i % _screens.length;
              AppLogger.nav(names[idx]);
              setState(() => _index = idx);
              _rootNavIndex.value = idx;
            },
            itemBuilder: (_, i) => _KeepAlivePage(child: _screens[i % _screens.length]),
          ),
          // Home FAB is now in MaterialApp.builder (above all pushed routes)
        ],
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onTap: _goTo,
      ),
    );
  }
}

/// Keeps screen state alive while swiping through the PageView.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.4);

    final items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
      _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Transactions'),
      _NavItem(Icons.repeat_rounded, Icons.repeat_rounded, 'Recurring'),
      null, // centre FAB placeholder
      _NavItem(Icons.savings_outlined, Icons.savings_rounded, 'Savings'),
      _NavItem(Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, 'Budget'),
      _NavItem(Icons.account_balance_wallet_outlined,
          Icons.account_balance_wallet_rounded, 'Accounts'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                      child: ListenableBuilder(
                        listenable: ThemeService.instance,
                        builder: (context, _) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: Colors.white, size: 26),
                          );
                        },
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
                          decoration: BoxDecoration(
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

