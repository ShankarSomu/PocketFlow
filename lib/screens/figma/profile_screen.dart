import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../db/database.dart';
import '../../services/app_logger.dart';
import '../../services/auth_service.dart';
import '../../services/refresh_notifier.dart';
import '../../services/seed_data.dart';
import '../../services/sms_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_color_scheme.dart';
import '../export_screen.dart';
import 'components/profile_hero_card.dart';
import 'components/profile_section_card.dart';
import 'components/profile_tile_row.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  String? _error;
  double _savingsRate = 0;
  double _budgetCompliance = 0;
  int _goalsOnTrack = 0;
  int _totalGoals = 0;

  @override
  void initState() {
    super.initState();
    _loadAccountHealth();
  }

  Future<void> _loadAccountHealth() async {
    try {
      final now = DateTime.now();
      final income = await AppDatabase.monthlyTotal('income', now.month, now.year);
      final expenses = await AppDatabase.monthlyTotal('expense', now.month, now.year);
      final savingsRate = income > 0
          ? ((income - expenses) / income * 100).clamp(0.0, 100.0)
          : 0.0;

      final budgets = await AppDatabase.getBudgets(now.month, now.year);
      final spent = await AppDatabase.monthlyExpenseByCategory(now.month, now.year);
      final budgetsWithLimit = budgets.where((b) => b.limit > 0).toList();
      int onTrackCount = 0;
      for (final b in budgetsWithLimit) {
        final spentAmount = spent[b.category] ?? 0;
        if (spentAmount <= b.limit) onTrackCount++;
      }
      final budgetCompliance = budgetsWithLimit.isNotEmpty
          ? (onTrackCount / budgetsWithLimit.length * 100)
          : 0.0;

      final goals = await AppDatabase.getGoals();
      final goalsOnTrack = goals.where((g) => g.progress >= 0.5).length;

      if (!mounted) return;
      setState(() {
        _savingsRate = savingsRate;
        _budgetCompliance = budgetCompliance;
        _goalsOnTrack = goalsOnTrack;
        _totalGoals = goals.length;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load account health: $e';
      });
    }
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    final user = await AuthService.signIn();
    if (!mounted) return;
    setState(() => _loading = false);
    if (user != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Signed in as ${user.email}')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sign in failed')));
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    await AuthService.clearSelectedFolder();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Signed out')));
  }

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
            'This will permanently delete all transactions, accounts, budgets, savings goals and recurring transactions. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete Everything')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await AppDatabase.deleteAllData();
      notifyDataChanged();
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted successfully')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppLogger.err('profile_delete_all_data', e);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to delete data')));
    }
  }

  Future<void> _loadSampleData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Sample Data?'),
        content: const Text(
            'This will populate your app with 13 months of realistic demo data including accounts, transactions, budgets, savings goals, and recurring transactions. This is useful for testing and exploring features.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Load Data')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await SeedData.load();
      notifyDataChanged();
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample data loaded successfully! 🎉')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppLogger.err('profile_load_sample_data', e);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to load sample data')));
    }
  }

  Future<void> _rescanSms() async {
    setState(() => _loading = true);
    try {
      final result = await SmsService.scanAndImport(force: true);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SMS scan complete! Found ${result.imported} transactions')),
      );
      notifyDataChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppLogger.err('profile_rescan_sms', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to scan SMS')),
      );
    }
  }

  Future<void> _inviteFriends() async {
    const playStoreLink = 'https://play.google.com/store/apps/details?id=com.pocketflow.app';
    const message = 'Check out PocketFlow - Smart expense tracking made easy! $playStoreLink';
    
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {'body': message},
    );
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open SMS app')),
      );
    }
  }

  Future<void> _rateApp() async {
    const packageName = 'com.pocketflow.app';
    final uri = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Play Store')),
      );
    }
  }

  Future<void> _contactUs() async {
    const email = 'support@pocketflow.app';
    const subject = 'Feedback:';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': subject},
    );
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app')),
      );
    }
  }

  void _showSubscription() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Subscription'),
        content: const Text('Free Plan\n\nYou are currently on the free plan with unlimited access to all features.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help'),
        content: const Text('Help documentation coming soon!\n\nIn the meantime, explore the app features or contact us for assistance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final isSignedIn = AuthService.isSignedIn;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            Navigator.pop(context);
          }
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.75,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(8, 0),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              child: SafeArea(
                child: _loading
                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                  : ListenableBuilder(
                      listenable: ThemeService.instance,
                      builder: (context, _) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              ProfileHeroCard(
                                user: user,
                                isSignedIn: isSignedIn,
                                savingsRate: _savingsRate,
                                budgetCompliance: _budgetCompliance,
                                goalsOnTrack: _goalsOnTrack,
                                totalGoals: _totalGoals,
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                          ProfileSectionCard(
                                            title: 'Account',
                                            icon: Icons.manage_accounts_rounded,
                                            children: [
                                              ProfileTileRow(
                                                icon: isSignedIn ? Icons.logout_rounded : Icons.login_rounded,
                                                label: isSignedIn ? 'Sign Out' : 'Sign In',
                                                color: isSignedIn
                                                    ? Theme.of(context).extension<AppColorScheme>()!.error
                                                    : Theme.of(context).extension<AppColorScheme>()!.success,
                                                onTap: isSignedIn ? _signOut : _signIn,
                                              ),
                                              if (isSignedIn) ...[ 
                                                Divider(height: 1, color: Theme.of(context).dividerColor),
                                                ProfileTileRow(
                                                  icon: Icons.delete_forever_rounded,
                                                  label: 'Delete All Data',
                                                  color: Theme.of(context).extension<AppColorScheme>()!.error,
                                                  onTap: _deleteAllData,
                                                ),
                                              ],
                                            ],
                                          ),
                                      const SizedBox(height: 6),
                                      ProfileSectionCard(
                                        title: 'Menu',
                                            icon: Icons.menu_rounded,
                                            children: [
                                              ProfileTileRow(
                                                icon: Icons.settings_rounded,
                                                label: 'Settings',
                                                color: Theme.of(context).colorScheme.primary,
                                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                                              ),
                                              Divider(height: 1, color: Theme.of(context).dividerColor),
                                              ProfileTileRow(
                                                icon: Icons.file_download_rounded,
                                                label: 'Export Data',
                                                color: Theme.of(context).extension<AppColorScheme>()!.primary,
                                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen())),
                                              ),
                                              Divider(height: 1, color: Theme.of(context).dividerColor),
                                              ProfileTileRow(
                                                icon: Icons.sms_rounded,
                                                label: 'Rescan SMS',
                                                color: Theme.of(context).extension<AppColorScheme>()!.primary,
                                                onTap: _rescanSms,
                                              ),
                                              Divider(height: 1, color: Theme.of(context).dividerColor),
                                              ProfileTileRow(
                                                icon: Icons.share_rounded,
                                                label: 'Invite Friends',
                                                color: Theme.of(context).extension<AppColorScheme>()!.success,
                                                onTap: _inviteFriends,
                                              ),
                                              Divider(height: 1, color: Theme.of(context).dividerColor),
                                              ProfileTileRow(
                                                icon: Icons.star_rounded,
                                                label: 'Rate PocketFlow',
                                                color: Theme.of(context).extension<AppColorScheme>()!.warning,
                                                onTap: _rateApp,
                                              ),
                                              Divider(height: 1, color: Theme.of(context).dividerColor),
                                              ProfileTileRow(
                                                icon: Icons.email_rounded,
                                                label: 'Contact Us',
                                                color: Theme.of(context).extension<AppColorScheme>()!.primary,
                                                onTap: _contactUs,
                                              ),
                                              Divider(height: 1, color: Theme.of(context).dividerColor),
                                              ProfileTileRow(
                                                icon: Icons.card_membership_rounded,
                                                label: 'Subscription',
                                                color: Theme.of(context).colorScheme.secondary,
                                                onTap: _showSubscription,
                                              ),
                                              Divider(height: 1, color: Theme.of(context).dividerColor),
                                              ProfileTileRow(
                                                icon: Icons.help_rounded,
                                                label: 'Help',
                                                color: Theme.of(context).extension<AppColorScheme>()!.primary,
                                                onTap: _showHelp,
                                              ),
                                            ],
                                          ),
                                      const SizedBox(height: 6),
                                      ProfileSectionCard(
                                        title: 'Developer',
                                            icon: Icons.code_rounded,
                                            children: [
                                              ProfileTileRow(
                                                icon: Icons.data_object_rounded,
                                                label: 'Load Sample Data',
                                                color: Theme.of(context).extension<AppColorScheme>()!.primary,
                                                onTap: _loadSampleData,
                                              ),
                                            ],
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
