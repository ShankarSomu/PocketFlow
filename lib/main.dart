import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pocket_flow/core/app_dependencies.dart';
import 'package:pocket_flow/screens/accounts/accounts_screen.dart';
import 'package:pocket_flow/screens/budget/budget_screen.dart';
import 'package:pocket_flow/screens/chat/chat_screen.dart';
import 'package:pocket_flow/screens/home/home_screen.dart';
import 'package:pocket_flow/screens/profile/profile_screen.dart';
import 'package:pocket_flow/screens/recurring/recurring_screen.dart';
import 'package:pocket_flow/screens/savings/savings_screen.dart';
import 'package:pocket_flow/screens/transactions/transactions_screen.dart';
import 'package:pocket_flow/screens/tutorial_overlay.dart';
import 'package:pocket_flow/screens/welcome_screen.dart';
import 'package:pocket_flow/services/app_logger.dart';
import 'package:pocket_flow/services/auth_service.dart';
import 'package:pocket_flow/services/deep_link_service.dart';
import 'package:pocket_flow/services/image_cache_service.dart';
import 'package:pocket_flow/services/ml_sms_classifier.dart';
import 'package:pocket_flow/services/navigation_state.dart';
import 'package:pocket_flow/services/sms_keyword_service.dart';
import 'services/notification_manager.dart';
import 'services/notification_service.dart';
import 'services/recurring_scheduler.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'utils/performance_utils.dart';
import 'widgets/feature_hint.dart';

// Global hybrid SMS parser instance (rule-based + ML)
late final HybridSmsParser hybridSmsParser;

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
  
  // Initialize ML SMS parser early (needed for SMS import)
  hybridSmsParser = HybridSmsParser();
  try {
    await hybridSmsParser.initialize();
    AppLogger.log(
      LogLevel.info,
      LogCategory.system,
      'ML SMS Classifier initialized',
      detail: 'Hybrid parser ready (rules + ML)',
    );
  } catch (e) {
    // Log error but don't crash app - parser will fall back to rules-only mode
    AppLogger.log(
      LogLevel.warning,
      LogCategory.system,
      'ML SMS Classifier initialization failed',
      detail: 'Falling back to rules-only mode: $e',
    );
  }
  
  // Initialize critical services in parallel to speed up boot
  await Future.wait([
    AuthService.init(),
    ThemeService.instance.init(),
    NavigationState.init(),
    DeepLinkService().init(),
    ImageCacheService().init(),
    NotificationService.initialize(),
    NotificationManager.instance.init(),
  ]);

  // Initialize SMS keyword service in background (non-blocking)
  // This loads keywords from database but won't block app startup
  SmsKeywordService.initialize().catchError((e) {
    AppLogger.log(
      LogLevel.error,
      LogCategory.system,
      'SMS keyword service initialization failed',
      detail: '$e',
    );
  });

  // Disabled while weekly summary scheduling is crashing in
  // flutter_local_notifications on Android.
  PerformanceMonitor.init();
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
      // Show tutorial for first-time users, then prompt sign-in
      if (_isFirstTime) {
        _showTutorial();
      } else {
        _promptSignIn();
      }
    }
  }

  Future<void> _showTutorial() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    
    final shouldShow = await TutorialOverlay.shouldShow();
    if (!shouldShow || !mounted) {
      _promptSignIn();
      return;
    }
    
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => TutorialOverlay(
          onComplete: () {
            Navigator.of(context).pop();
            _promptSignIn();
          },
        ),
      ),
    );
  }

  Future<void> _promptSignIn() async {
    // Wait a bit for the UI to settle
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    final shouldSignIn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Sign In to PocketFlow'),
          ],
        ),
        content: const Text(
          'Sign in to sync your data across devices and enable automatic backups to Google Drive.\n\nYou can always sign in later from the profile menu.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip for now'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Sign In'),
          ),
        ],
      ),
    );

    if ((shouldSignIn ?? false) && mounted) {
      final user = await AuthService.signIn();
      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${user.displayName ?? user.email}!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeService.instance.buildLightTheme(),
        darkTheme: ThemeService.instance.buildDarkTheme(),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

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
          home: _showWelcome
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
    _restoreLastTab();
    _pageCtrl = PageController(initialPage: 7 * 500);
    _rootGoHome = () => _goTo(0);
    _setupDeepLinkHandler();
  }

  /// Set up deep link navigation handler
  void _setupDeepLinkHandler() {
    DeepLinkService().onLinkReceived = (deepLink) {
      AppLogger.log(
        LogLevel.info,
        LogCategory.navigation,
        'Deep link received',
        detail: deepLink.toString(),
      );

      // Navigate based on deep link route
      switch (deepLink.route) {
        case 'home':
          _goTo(0);
          break;
        case 'transactions':
          _goTo(1);
          break;
        case 'transactions/add':
          _goTo(1);
          // TODO: Open add transaction dialog
          break;
        case 'accounts':
          _goTo(6);
          break;
        case 'budgets':
          _goTo(5);
          break;
        case 'goals':
          _goTo(4);
          break;
        case 'settings':
          // Navigate to profile screen (not in bottom nav)
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
          break;
        case 'chat':
          _goTo(3);
          break;
        default:
          AppLogger.log(
            LogLevel.warning,
            LogCategory.navigation,
            'Unknown deep link route',
            detail: deepLink.route,
          );
      }
    };
  }

  Future<void> _restoreLastTab() async {
    final lastTab = await NavigationState.getLastTab();
    if (lastTab != 0 && mounted) {
      setState(() => _index = lastTab);
      _rootNavIndex.value = lastTab;
      // Update page controller after it's initialized
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageCtrl.hasClients) {
          final currentPage = _pageCtrl.page?.round() ?? (_screens.length * 500);
          final currentSlot = currentPage % _screens.length;
          int diff = (lastTab - currentSlot) % _screens.length;
          if (diff > _screens.length ~/ 2) diff -= _screens.length;
          if (diff != 0) {
            _pageCtrl.jumpToPage(currentPage + diff);
          }
        }
      });
    }
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
    NavigationState.saveLastTab(i); // Persist tab change
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
      body: FeatureHint(
        featureKey: FeatureHints.swipeNavigation,
        message: 'Swipe left or right to navigate between screens',
        alignment: Alignment.center,
        delay: const Duration(seconds: 2),
        child: Stack(
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
                NavigationState.saveLastTab(idx); // Persist swipe navigation
              },
              itemBuilder: (_, i) => _KeepAlivePage(child: _screens[i % _screens.length]),
            ),
            // Home FAB is now in MaterialApp.builder (above all pushed routes)
          ],
        ),
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
  const _KeepAlivePage({required this.child});
  final Widget child;
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
  const _BottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);

    final items = [
      const _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
      const _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Transactions'),
      const _NavItem(Icons.repeat_rounded, Icons.repeat_rounded, 'Recurring'),
      null, // centre FAB placeholder
      const _NavItem(Icons.savings_outlined, Icons.savings_rounded, 'Savings'),
      const _NavItem(Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, 'Budget'),
      const _NavItem(Icons.account_balance_wallet_outlined,
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
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}


