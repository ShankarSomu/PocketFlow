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
import 'package:pocket_flow/sms_engine/_ml_deprecated/sms_ml_classifier.dart';
import 'package:pocket_flow/services/navigation_state.dart';
import 'package:pocket_flow/sms_engine/ingestion/sms_keyword_service.dart';
import 'services/notification_manager.dart';
import 'services/notification_service.dart';
import 'services/refresh_notifier.dart' as refreshNotifier;
import 'services/theme_service.dart';
import 'services/unified_rule_engine.dart';
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
  UnifiedRuleEngine.processToday();
  refreshNotifier.appRefresh.addListener(() {
    UnifiedRuleEngine.processToday();
  });
  runApp(const PocketFlowApp());
}

// Global nav-index notifier – updated by _RootNavState so the FAB in the
// MaterialApp builder can react even when Profile/Settings are pushed on top.
final _rootNavIndex = ValueNotifier<int>(0);
VoidCallback? _rootGoHome;
final _appNavigatorKey = GlobalKey<NavigatorState>();

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final nav = _appNavigatorKey.currentState;
      if (nav == null) { _promptSignIn(); return; }
      try {
        await nav.push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => TutorialOverlay(
              onComplete: () {
                nav.pop();
                _promptSignIn();
              },
            ),
          ),
        );
      } catch (e) {
        // If Navigator is not available, fallback gracefully
        _promptSignIn();
      }
    });
  }

  Future<void> _promptSignIn() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final nav = _appNavigatorKey.currentState;
      if (nav == null) return;

      bool? shouldSignIn;
      try {
        shouldSignIn = await showModalBottomSheet<bool>(
          context: nav.context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => _SignInBottomSheet(
            onSignIn: () => Navigator.pop(ctx, true),
            onSkip: () => Navigator.pop(ctx, false),
          ),
        );
      } catch (e) {
        return;
      }

      if ((shouldSignIn ?? false) && mounted) {
        final user = await AuthService.signIn();
        final ctx = _appNavigatorKey.currentContext;
        if (user != null && ctx != null && mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('Welcome, ${user.displayName ?? user.email}! 👋'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(ctx).colorScheme.primary,
            ),
          );
          await _promptRestoreAfterSignIn();
        }
      }
    });
  }

  Future<void> _promptRestoreAfterSignIn() async {
    if (!mounted || !AuthService.isSignedIn) return;

    final nav = _appNavigatorKey.currentState;
    if (nav == null) return;

    try {
      final folder = await AuthService.ensureSelectedBackupFolder(
        createIfMissing: false,
      );
      if (folder == null) return;

      final hasBackup = await AuthService.hasBackupInSelectedFolder();
      if (!hasBackup || !mounted) return;

      final shouldRestore = await showDialog<bool>(
        context: nav.context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Backup Found'),
          content: Text(
            'We found a Google Drive backup in "${folder.name}".\n\n'
            'Do you want to restore your data, or skip and start fresh?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Start fresh'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: const Text('Restore backup'),
            ),
          ],
        ),
      );

      if (shouldRestore != true || !mounted) return;

      final messengerCtx = _appNavigatorKey.currentContext;
      if (messengerCtx != null) {
        ScaffoldMessenger.of(messengerCtx).showSnackBar(
          const SnackBar(content: Text('Restoring backup...')),
        );
      }

      await AuthService.restore();
      refreshNotifier.notifyDataChanged();

      final successCtx = _appNavigatorKey.currentContext;
      if (successCtx != null && mounted) {
        ScaffoldMessenger.of(successCtx).showSnackBar(
          SnackBar(
            content: const Text('Backup restored successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(successCtx).colorScheme.tertiary,
          ),
        );
      }
    } catch (_) {
      final errCtx = _appNavigatorKey.currentContext;
      if (errCtx != null && mounted) {
        ScaffoldMessenger.of(errCtx).showSnackBar(
          SnackBar(
            content: const Text('Backup restore failed. Starting with current data.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(errCtx).colorScheme.error,
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
          navigatorKey: _appNavigatorKey,
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
  final _screens = [
    HomeScreen(),
    TransactionsScreen(),
    RecurringScreen(),
    ChatScreen(),
    GoalsScreen(),
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
    const names = ['Home','Transactions','Recurring','Chat','Goals','Budget','Accounts'];
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
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: _screens.length * 1000, // Infinite loop simulation
        onPageChanged: (pageIndex) {
          final nextIndex = pageIndex % _screens.length;
          if (_index == nextIndex) return;
          setState(() => _index = nextIndex);
          _rootNavIndex.value = nextIndex;
          NavigationState.saveLastTab(nextIndex);
        },
        itemBuilder: (context, index) {
          final screenIndex = index % _screens.length;
          return _KeepAlivePage(child: _screens[screenIndex]);
        },
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
        _NavItem(Icons.emoji_events_outlined, Icons.emoji_events, 'Goals'),
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

// ─── Sign-in bottom sheet ─────────────────────────────────────────────────────

class _SignInBottomSheet extends StatelessWidget {
  const _SignInBottomSheet({required this.onSignIn, required this.onSkip});
  final VoidCallback onSignIn;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final size = MediaQuery.of(context).size;

    return Container(
      width: size.width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),
              // Icon badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary, Color.lerp(primary, Colors.purple, 0.4)!],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.sync_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Keep your data safe',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Sign in with Google to sync across devices and back up automatically to Google Drive.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Feature pills
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FeaturePill(icon: Icons.devices_rounded, label: 'Multi-device', primary: primary),
                  const SizedBox(width: 10),
                  _FeaturePill(icon: Icons.backup_rounded, label: 'Auto backup', primary: primary),
                  const SizedBox(width: 10),
                  _FeaturePill(icon: Icons.lock_outline_rounded, label: 'Private', primary: primary),
                ],
              ),
              const SizedBox(height: 28),
              // Sign in button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text('Continue with Google'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Skip button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Maybe later',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.primary,
  });
  final IconData icon;
  final String label;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}


