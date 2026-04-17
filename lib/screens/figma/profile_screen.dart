import 'package:flutter/material.dart';
import '../../db/database.dart';
import '../../services/app_logger.dart';
import '../../services/auth_service.dart';
import '../../services/refresh_notifier.dart';
import '../../services/seed_data.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import 'shared.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
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
    });
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
    });
    final user = await AuthService.signIn();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
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

  Future<void> _showProfileMenu() async {
    final user = AuthService.currentUser;
    final isSignedIn = AuthService.isSignedIn;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSignedIn) ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                  child: user?.photoUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(user?.displayName ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(user?.email ?? '',
                    style: const TextStyle(fontSize: 12)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sign Out',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _signOut();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete All Data',
                    style: TextStyle(color: Colors.red)),
                subtitle: const Text('Permanently delete all local data',
                    style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteAllData();
                },
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Sign in to access backups and premium features',
                    style: TextStyle(color: Colors.grey)),
              ),
              ListTile(
                leading: const Icon(Icons.login, color: Colors.blue),
                title: const Text('Sign in with Google'),
                onTap: () {
                  Navigator.pop(ctx);
                  _signIn();
                },
              ),
            ],
          ],
        ),
      ),
    );
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
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete Everything')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _loading = true;
    });
    try {
      await AppDatabase.deleteAllData();
      notifyDataChanged();
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted successfully')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
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

    setState(() {
      _loading = true;
    });
    try {
      await SeedData.load();
      notifyDataChanged();
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample data loaded successfully! 🎉')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      AppLogger.err('profile_load_sample_data', e);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to load sample data')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final isSignedIn = AuthService.isSignedIn;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.emerald))
            : ListenableBuilder(
                listenable: ThemeService.instance,
                builder: (context, _) {
                  return Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: AppTheme.cardShadow,
                                ),
                                child: Icon(Icons.person_rounded,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
                              ),
                              Expanded(
                                child: Text(
                                  'Profile',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.onSurface),
                                ),
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _ProfileHeroCard(
                            user: user,
                            isSignedIn: isSignedIn,
                            savingsRate: _savingsRate,
                            budgetCompliance: _budgetCompliance,
                            goalsOnTrack: _goalsOnTrack,
                            totalGoals: _totalGoals,
                            onAvatarTap: _showProfileMenu,
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            children: [
                              _SectionCard(
                                title: 'Account',
                                icon: Icons.manage_accounts_rounded,
                                children: [
                                  _TileRow(
                                    icon: isSignedIn
                                        ? Icons.logout_rounded
                                        : Icons.login_rounded,
                                    label: isSignedIn
                                        ? 'Sign Out'
                                        : 'Sign In with Google',
                                    color: isSignedIn
                                        ? AppTheme.error
                                        : AppTheme.emerald,
                                    onTap: isSignedIn ? _signOut : _signIn,
                                  ),
                                  if (isSignedIn) ...[
                                    Divider(height: 1, color: Theme.of(context).dividerColor),
                                    _TileRow(
                                      icon: Icons.delete_forever_rounded,
                                      label: 'Delete All Data',
                                      color: AppTheme.error,
                                      onTap: _deleteAllData,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              _SectionCard(
                                title: 'Developer',
                                icon: Icons.code_rounded,
                                children: [
                                  _TileRow(
                                    icon: Icons.data_object_rounded,
                                    label: 'Load Sample Data',
                                    color: AppTheme.blue,
                                    onTap: _loadSampleData,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  final dynamic user;
  final bool isSignedIn;
  final double savingsRate, budgetCompliance;
  final int goalsOnTrack, totalGoals;
  final VoidCallback onAvatarTap;

  const _ProfileHeroCard({
    required this.user,
    required this.isSignedIn,
    required this.savingsRate,
    required this.budgetCompliance,
    required this.goalsOnTrack,
    required this.totalGoals,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2E22), Color(0xFF14532D), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppTheme.emeraldGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: user?.photoUrl != null
                      ? ClipOval(
                          child: Image.network(user!.photoUrl!, fit: BoxFit.cover))
                      : const Icon(Icons.person_rounded,
                          size: 32, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Profile',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isSignedIn ? (user?.email ?? '') : 'Not signed in',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isSignedIn ? 'Premium Member' : 'Guest',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Savings Rate',
                  value: '${savingsRate.toStringAsFixed(0)}%',
                  good: savingsRate >= 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Budget',
                  value: '${budgetCompliance.toStringAsFixed(0)}%',
                  good: budgetCompliance >= 80,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Goals',
                  value: '$goalsOnTrack/$totalGoals',
                  good: goalsOnTrack == totalGoals && totalGoals > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final bool good;
  const _StatChip({required this.label, required this.value, required this.good});

  @override
  Widget build(BuildContext context) {
    final color = good ? const Color(0xFF34D399) : const Color(0xFFFBBF24);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.slate500,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                color: AppTheme.slate900,
                fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool fullWidth;
  const _OutlineActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: AppTheme.emerald),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate700)),
          ],
        ),
      ),
    );
  }
}

class _TileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _TileRow({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

