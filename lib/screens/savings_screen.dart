import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/savings_goal.dart';
import '../models/account.dart';
import '../services/refresh_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_text.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});
  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  List<SavingsGoal> _goals = [];
  List<Account> _accounts = [];
  Map<int, double> _accountBalances = {};
  Map<int, double> _monthlyContributions = {};
  bool _loading = true;

  String _getEmojiForGoal(String name) {
    final n = name.toLowerCase();
    if (n.contains('emergency') || n.contains('fund') || n.contains('safety')) return '🛡️';
    if (n.contains('car') || n.contains('vehicle') || n.contains('auto')) return '🚗';
    if (n.contains('vacation') || n.contains('travel') || n.contains('trip') || n.contains('holiday')) return '✈️';
    if (n.contains('house') || n.contains('home') || n.contains('property')) return '🏡';
    if (n.contains('wedding') || n.contains('marriage')) return '💍';
    if (n.contains('education') || n.contains('college') || n.contains('school')) return '🎓';
    if (n.contains('retirement') || n.contains('pension')) return '🌴';
    if (n.contains('baby') || n.contains('child') || n.contains('kid')) return '👶';
    if (n.contains('business') || n.contains('startup')) return '💼';
    if (n.contains('computer') || n.contains('laptop') || n.contains('tech')) return '💻';
    if (n.contains('phone') || n.contains('iphone')) return '📱';
    if (n.contains('bike') || n.contains('bicycle')) return '🚴';
    if (n.contains('gift') || n.contains('present')) return '🎁';
    if (n.contains('pet') || n.contains('dog') || n.contains('cat')) return '🐾';
    return '🎯';
  }

  @override
  void initState() {
    super.initState();
    _load();
    appRefresh.addListener(_load);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final goals = await AppDatabase.getGoals();
    final accounts = await AppDatabase.getAccounts();
    final recurring = await AppDatabase.getRecurring();
    final balances = <int, double>{};
    for (final a in accounts) {
      balances[a.id!] = await AppDatabase.accountBalance(a.id!, a);
    }
    // Build monthly contribution map: goalId -> monthly amount from recurring
    final monthlyContributions = <int, double>{};
    for (final r in recurring) {
      if (r.isActive && r.type == 'goal' && r.goalId != null) {
        final monthly = _toMonthlyAmount(r.amount, r.frequency);
        monthlyContributions[r.goalId!] =
            (monthlyContributions[r.goalId!] ?? 0) + monthly;
      }
    }
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _accounts = accounts;
      _accountBalances = balances;
      _monthlyContributions = monthlyContributions;
      _loading = false;
    });
  }

  double _toMonthlyAmount(double amount, String frequency) {
    return switch (frequency) {
      'daily'       => amount * 30,
      'weekly'      => amount * 4.33,
      'biweekly'    => amount * 2.17,
      'half-yearly' => amount / 6,
      'yearly'      => amount / 12,
      _             => amount, // monthly
    };
  }

  // ── Allocation logic ────────────────────────────────────────────────────────

  /// For each account, distribute balance across goals by priority order.
  /// Returns map of goalId -> allocated amount
  Map<int, double> _computeAllocations() {
    // Group goals by account
    final Map<int, List<SavingsGoal>> byAccount = {};
    for (final g in _goals) {
      if (g.accountId == null) continue;
      byAccount.putIfAbsent(g.accountId!, () => []).add(g);
    }

    final allocations = <int, double>{};

    for (final entry in byAccount.entries) {
      final accountId = entry.key;
      final accountGoals = entry.value
        ..sort((a, b) => a.priority.compareTo(b.priority));
      double remaining = _accountBalances[accountId] ?? 0;

      for (final g in accountGoals) {
        final needed = g.remaining;
        final allocated = needed <= remaining ? needed : remaining;
        allocations[g.id!] = allocated;
        remaining -= allocated;
        if (remaining <= 0) break;
      }
      // Goals that didn't get allocated
      for (final g in accountGoals) {
        allocations.putIfAbsent(g.id!, () => 0);
      }
    }
    return allocations;
  }

  double _monthlyIncomeForAccount(int accountId) {
    return 0;
  }

  Future<void> _applyAllocations() async {
    final allocations = _computeAllocations();
    for (final g in _goals) {
      final alloc = allocations[g.id];
      if (alloc != null && alloc != g.saved) {
        await AppDatabase.updateGoalSaved(g.id!, alloc);
      }
    }
    notifyDataChanged();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Allocations applied!')),
    );
  }

  void _showForm([SavingsGoal? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final targetCtrl = TextEditingController(
        text: existing?.target.toStringAsFixed(2) ?? '');
    final savedCtrl = TextEditingController(
        text: existing?.saved.toStringAsFixed(2) ?? '0');
    int? accountId = existing?.accountId;
    int priority = existing?.priority ?? (_goals.length + 1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'New Savings Goal' : 'Edit Goal',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Goal Name',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Target Amount',
                      prefixText: '\$',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: savedCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Already Saved',
                      prefixText: '\$',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                // Account picker
                DropdownButtonFormField<int?>(
                  value: accountId,
                  decoration: const InputDecoration(
                      labelText: 'Linked Account (optional)',
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('No account')),
                    ..._accounts.map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                            '${a.name} (\$${(_accountBalances[a.id] ?? 0).toStringAsFixed(0)})'))),
                  ],
                  onChanged: (v) => setLocal(() => accountId = v),
                ),
                const SizedBox(height: 12),
                // Priority
                Row(children: [
                  const Text('Priority: ',
                      style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: priority.toDouble().clamp(1, 10),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: priority.toString(),
                      onChanged: (v) =>
                          setLocal(() => priority = v.round()),
                    ),
                  ),
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Text('$priority',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
                const Text(
                    '1 = highest priority, 10 = lowest',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 16),
                Row(children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Goal?'),
                            content: Text('Delete "${existing.name}"? This cannot be undone.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await AppDatabase.deleteGoal(existing.id!);
                        notifyDataChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final target = double.tryParse(targetCtrl.text);
                      final saved = double.tryParse(savedCtrl.text) ?? 0;
                      if (name.isEmpty || target == null || target <= 0) return;
                      final goal = SavingsGoal(
                        id: existing?.id,
                        name: name,
                        target: target,
                        saved: saved,
                        accountId: accountId,
                        priority: priority,
                      );
                      if (existing == null) {
                        await AppDatabase.insertGoal(goal);
                      } else {
                        await AppDatabase.updateGoal(goal);
                      }
                      notifyDataChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(existing == null ? 'Create' : 'Update'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final allocations = _computeAllocations();
    final totalTarget = _goals.fold(0.0, (sum, g) => sum + g.target);
    final totalCurrent = _goals.fold(0.0, (sum, g) => sum + g.saved);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF064E3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _goals.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flag_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'No goals yet.\nTap + to create one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Fixed Header
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [Colors.white, Color(0xFFD1FAE5)],
                                    ).createShader(bounds),
                                    child: const Text(
                                      'Goals',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w300,
                                        letterSpacing: -1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Track your financial goals',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Scrollable Content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          child: Column(
                            children: [

                      // Overall Progress Card
                      if (_goals.isNotEmpty) ...[
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween<double>(begin: 0, end: 1),
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.scale(
                                scale: 0.95 + (0.05 * value),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFFD946EF)],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(_goals.length <= 3 ? 20 : _goals.length <= 6 ? 16 : 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text('Total Goal Progress',
                                                style: TextStyle(color: Colors.white70, fontSize: _goals.length <= 3 ? 13 : _goals.length <= 6 ? 12 : 11)),
                                            const SizedBox(width: 6),
                                            Icon(Icons.emoji_events, color: Colors.white70, size: _goals.length <= 3 ? 16 : _goals.length <= 6 ? 15 : 14),
                                          ],
                                        ),
                                        SizedBox(height: _goals.length <= 3 ? 12 : _goals.length <= 6 ? 10 : 8),
                                        Text(fmt.format(totalCurrent),
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: _goals.length <= 3 ? 40 : _goals.length <= 6 ? 32 : 28,
                                                fontWeight: FontWeight.w300)),
                                        SizedBox(height: _goals.length <= 3 ? 4 : 2),
                                        Text('of ${fmt.format(totalTarget)} target',
                                            style: TextStyle(color: Colors.white70, fontSize: _goals.length <= 3 ? 14 : _goals.length <= 6 ? 13 : 12)),
                                      ],
                                    ),
                                    if (_goals.length <= 6)
                                      Container(
                                        width: _goals.length <= 3 ? 70 : 60,
                                        height: _goals.length <= 3 ? 70 : 60,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                        ),
                                        child: Icon(Icons.track_changes, color: Colors.white, size: _goals.length <= 3 ? 35 : 30),
                                      ),
                                  ],
                                ),
                                SizedBox(height: _goals.length <= 3 ? 16 : _goals.length <= 6 ? 12 : 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: totalTarget > 0 ? (totalCurrent / totalTarget).clamp(0.0, 1.0) : 0,
                                    minHeight: _goals.length <= 3 ? 10 : _goals.length <= 6 ? 8 : 6,
                                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                                  ),
                                ),
                                SizedBox(height: _goals.length <= 3 ? 10 : _goals.length <= 6 ? 8 : 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${totalTarget > 0 ? ((totalCurrent / totalTarget) * 100).toStringAsFixed(1) : "0.0"}% complete',
                                        style: TextStyle(color: Colors.white, fontSize: _goals.length <= 3 ? 12 : _goals.length <= 6 ? 11 : 10),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        '${fmt.format(totalTarget - totalCurrent)} remaining',
                                        style: TextStyle(color: Colors.white, fontSize: _goals.length <= 3 ? 12 : _goals.length <= 6 ? 11 : 10),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: _goals.length <= 3 ? 20 : _goals.length <= 6 ? 16 : 12),
                      ],

                      // Goal cards
                      ..._goals.asMap().entries.map((entry) {
                        final index = entry.key;
                        final g = entry.value;
                        final account = _accounts
                            .where((a) => a.id == g.accountId)
                            .firstOrNull;
                        final accountBalance =
                            g.accountId != null
                                ? (_accountBalances[g.accountId] ?? 0)
                                : null;
                        final allocated = allocations[g.id];
                        final totalGoals = _goals.length;
                        return TweenAnimationBuilder(
                          duration: Duration(milliseconds: 700 + (index * 100)),
                          tween: Tween<double>(begin: 0, end: 1),
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: _GoalCard(
                            goal: g,
                            emoji: _getEmojiForGoal(g.name),
                            account: account,
                            accountBalance: accountBalance,
                            allocated: allocated,
                            monthlyContribution: _monthlyContributions[g.id] ?? 0,
                            fmt: fmt,
                            onTap: () => _showForm(g),
                            onContribute: () => _showContribute(g),
                            totalGoals: totalGoals,
                          ),
                        );
                      }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppTheme.emerald.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add Goal'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
    );
  }

  void _showContribute(SavingsGoal goal) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to ${goal.name}'),
        content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Amount', prefixText: '\$')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null || amount <= 0) return;
              await AppDatabase.updateGoalSaved(
                  goal.id!, goal.saved + amount);
              notifyDataChanged();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ── Allocation Summary Card ───────────────────────────────────────────────────

class _AllocationSummary extends StatelessWidget {
  final List<SavingsGoal> goals;
  final List<Account> accounts;
  final Map<int, double> balances;
  final Map<int, double> allocations;
  final NumberFormat fmt;

  const _AllocationSummary({
    required this.goals,
    required this.accounts,
    required this.balances,
    required this.allocations,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    // Group by account
    final Map<int, List<SavingsGoal>> byAccount = {};
    for (final g in goals) {
      if (g.accountId == null) continue;
      byAccount.putIfAbsent(g.accountId!, () => []).add(g);
    }

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.account_balance, size: 16),
              SizedBox(width: 6),
              Text('Allocation Preview',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            ...byAccount.entries.map((entry) {
              final account = accounts
                  .where((a) => a.id == entry.key)
                  .firstOrNull;
              final balance = balances[entry.key] ?? 0;
              final totalAllocated = entry.value
                  .fold(0.0, (s, g) => s + (allocations[g.id] ?? 0));
              final unallocated = balance - totalAllocated;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account?.name ?? 'Account',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                      'Balance: ${fmt.format(balance)} · Unallocated: ${fmt.format(unallocated)}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  ...entry.value
                      .sorted((a, b) => a.priority.compareTo(b.priority))
                      .map((g) {
                    final alloc = allocations[g.id] ?? 0;
                    final funded = alloc >= g.remaining;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: funded
                                ? Colors.green
                                : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Text('${g.priority}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(g.name,
                                style:
                                    const TextStyle(fontSize: 12))),
                        Text(fmt.format(alloc),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: funded
                                    ? Colors.green
                                    : Colors.orange)),
                      ]),
                    );
                  }),
                  const Divider(),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Goal Card ─────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final String emoji;
  final Account? account;
  final double? accountBalance;
  final double? allocated;
  final double monthlyContribution;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onContribute;
  final int totalGoals;

  const _GoalCard({
    required this.goal,
    required this.emoji,
    required this.account,
    required this.accountBalance,
    required this.allocated,
    required this.monthlyContribution,
    required this.fmt,
    required this.onTap,
    required this.onContribute,
    required this.totalGoals,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).toStringAsFixed(1);
    final remaining = goal.target - goal.saved;

    // Dynamic sizing based on goal count
    final double emojiSize = totalGoals <= 3 ? 40 : totalGoals <= 6 ? 36 : 32;
    final double cardPadding = totalGoals <= 3 ? 16 : totalGoals <= 6 ? 12 : 10;
    final double titleSize = totalGoals <= 3 ? 15 : totalGoals <= 6 ? 14 : 13;
    final double amountSize = totalGoals <= 3 ? 18 : totalGoals <= 6 ? 16 : 14;
    final double subtitleSize = totalGoals <= 3 ? 11 : totalGoals <= 6 ? 10 : 9;
    final double progressHeight = totalGoals <= 3 ? 6 : totalGoals <= 6 ? 5 : 4;
    final double spacing = totalGoals <= 3 ? 12 : totalGoals <= 6 ? 10 : 8;

    return GlassCard(
      margin: EdgeInsets.only(bottom: spacing),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: emojiSize,
                    height: emojiSize,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emoji,
                      style: TextStyle(fontSize: emojiSize * 0.5),
                    ),
                  ),
                  SizedBox(width: cardPadding),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(goal.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: titleSize,
                                color: AppTheme.slate900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (totalGoals <= 6) SizedBox(height: 2),
                        if (totalGoals <= 6)
                          Text(
                            '$pct% complete',
                            style: TextStyle(
                              fontSize: subtitleSize,
                              color: AppTheme.slate500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: cardPadding),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmt.format(goal.saved),
                        style: TextStyle(
                            fontSize: amountSize,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.emerald),
                      ),
                      if (totalGoals <= 6)
                        Text(
                          'of ${fmt.format(goal.target)}',
                          style: TextStyle(
                            fontSize: subtitleSize - 1,
                            color: AppTheme.slate500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: spacing),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: progressHeight,
                  backgroundColor: const Color(0xFFE0E7FF),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _ListExt<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}

