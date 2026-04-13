import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database.dart';
import '../models/savings_goal.dart';
import '../models/account.dart';
import '../services/refresh_notifier.dart';

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
    final hasLinkedGoals = _goals.any((g) => g.accountId != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? const Center(
                  child: Text('No goals yet.\nTap + to create one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Account allocation summary ──────────────────────
                    if (hasLinkedGoals) ...[
                      _AllocationSummary(
                        goals: _goals,
                        accounts: _accounts,
                        balances: _accountBalances,
                        allocations: allocations,
                        fmt: fmt,
                      ),
                      const SizedBox(height: 16),
                    ],
                    // ── Goal cards ──────────────────────────────────────
                    ..._goals.map((g) {
                      final account = _accounts
                          .where((a) => a.id == g.accountId)
                          .firstOrNull;
                      final accountBalance =
                          g.accountId != null
                              ? (_accountBalances[g.accountId] ?? 0)
                              : null;
                      final allocated = allocations[g.id];
                      return _GoalCard(
                        goal: g,
                        account: account,
                        accountBalance: accountBalance,
                        allocated: allocated,
                        monthlyContribution: _monthlyContributions[g.id] ?? 0,
                        fmt: fmt,
                        onTap: () => _showForm(g),
                        onContribute: () => _showContribute(g),
                      );
                    }),
                  ],
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
  final Account? account;
  final double? accountBalance;
  final double? allocated;
  final double monthlyContribution;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onContribute;

  const _GoalCard({
    required this.goal,
    required this.account,
    required this.accountBalance,
    required this.allocated,
    required this.monthlyContribution,
    required this.fmt,
    required this.onTap,
    required this.onContribute,
  });

  /// Estimate completion based on monthly recurring income to the account
  String _estimateLabel(double monthlyIncome) {
    if (goal.remaining <= 0) return '✓ Goal reached!';
    if (monthlyIncome <= 0) return 'Add a Recurring Goal entry to see estimate';
    final est = goal.estimateCompletion(monthlyIncome);
    if (est == null) return '';
    final months = est.difference(DateTime.now()).inDays ~/ 30;
    if (months <= 0) return 'Almost there!';
    if (months == 1) return 'Est. completion: next month';
    return 'Est. completion: ${DateFormat('MMM yyyy').format(est)} ($months months)';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).toStringAsFixed(1);
    final accountFunded = accountBalance != null &&
        accountBalance! >= goal.remaining;
    final allocationColor = allocated == null
        ? Colors.blue
        : allocated! >= goal.remaining
            ? Colors.green
            : allocated! > 0
                ? Colors.orange
                : Colors.red;

    // Use recurring contribution if available, else fall back to 10% of balance
    final monthlyEstimate = monthlyContribution > 0
        ? monthlyContribution
        : (accountBalance != null ? accountBalance! * 0.1 : 0.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(children: [
                          if (goal.priority < 999)
                            Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(right: 8),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6C63FF),
                                shape: BoxShape.circle,
                              ),
                              child: Text('${goal.priority}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          Expanded(
                            child: Text(goal.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ),
                        ]),
                      ),
                      TextButton.icon(
                        onPressed: onContribute,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ]),

                // Account badge
                if (account != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.account_balance_wallet,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(account!.name,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Icon(
                      accountFunded
                          ? Icons.check_circle
                          : Icons.warning_amber,
                      size: 12,
                      color: accountFunded ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      accountFunded
                          ? 'Funded'
                          : 'Needs ${fmt.format(goal.remaining - (accountBalance ?? 0))} more',
                      style: TextStyle(
                          fontSize: 11,
                          color: accountFunded
                              ? Colors.green
                              : Colors.orange),
                    ),
                  ]),
                ],

                const SizedBox(height: 10),

                // Progress bar
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: goal.progress,
                      minHeight: 22,
                      backgroundColor: Colors.blue.withValues(alpha: 0.12),
                      valueColor:
                          AlwaysStoppedAnimation(allocationColor),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Text('$pct%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                ]),

                const SizedBox(height: 8),

                // Amounts row
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Saved: ${fmt.format(goal.saved)}',
                          style: const TextStyle(fontSize: 13)),
                      Text('Target: ${fmt.format(goal.target)}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
                    ]),

                // Allocation row
                if (allocated != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.auto_fix_high,
                        size: 12, color: allocationColor),
                    const SizedBox(width: 4),
                    Text(
                      'Allocated: ${fmt.format(allocated!)}',
                      style: TextStyle(
                          fontSize: 11, color: allocationColor),
                    ),
                    if (allocated! < goal.remaining) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${fmt.format(goal.remaining - allocated!)} short)',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.red),
                      ),
                    ],
                  ]),
                ],

                // Estimate
                const SizedBox(height: 4),
                Text(
                  _estimateLabel(monthlyEstimate),
                  style: TextStyle(
                      fontSize: 11,
                      color: goal.remaining <= 0
                          ? Colors.green
                          : Colors.grey),
                ),
              ]),
        ),
      ),
    );
  }
}

extension _ListExt<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}

