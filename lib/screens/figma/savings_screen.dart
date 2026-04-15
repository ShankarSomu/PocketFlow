import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../models/account.dart';
import '../../models/savings_goal.dart';
import '../../services/refresh_notifier.dart';
import '../../theme/app_theme.dart';
import 'shared.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  bool _loading = true;
  List<SavingsGoal> _goals = [];
  List<Account> _accounts = [];
  Map<int, double> _accountBalances = {};

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
    final balances = <int, double>{};
    for (final a in accounts) {
      balances[a.id!] = await AppDatabase.accountBalance(a.id!, a);
    }
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _accounts = accounts;
      _accountBalances = balances;
      _loading = false;
    });
  }

  String _emojiForGoal(String name) {
    final n = name.toLowerCase();
    if (n.contains('emergency') || n.contains('fund')) return '🛡️';
    if (n.contains('car')) return '🚗';
    if (n.contains('vacation') || n.contains('travel')) return '✈️';
    if (n.contains('home')) return '🏡';
    if (n.contains('wedding')) return '💍';
    if (n.contains('education')) return '🎓';
    return '🎯';
  }

  void _showForm([SavingsGoal? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final targetCtrl = TextEditingController(text: existing?.target.toStringAsFixed(2) ?? '');
    final savedCtrl = TextEditingController(text: existing?.saved.toStringAsFixed(2) ?? '0');
    int? accountId = existing?.accountId;
    int priority = existing?.priority ?? (_goals.length + 1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Create Savings Goal' : 'Edit Savings Goal',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Goal Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Target Amount', prefixText: '\$', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: savedCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Already Saved', prefixText: '\$', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: accountId,
                  decoration: const InputDecoration(labelText: 'Linked Account (optional)', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No account')),
                    ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${_accountBalances[a.id] != null ? '\$${_accountBalances[a.id]!.toStringAsFixed(0)}' : '0'})'))),
                  ],
                  onChanged: (v) => setLocal(() => accountId = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Priority: ', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: priority.toDouble().clamp(1, 10),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: priority.toString(),
                      onChanged: (v) => setLocal(() => priority = v.round()),
                    ),
                  ),
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Text('$priority', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Goal?'),
                            content: Text('Delete "${existing.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
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
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                    child: Text(existing == null ? 'Create' : 'Save'),
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
    final totalTarget = _goals.fold(0.0, (sum, g) => sum + g.target);
    final totalSaved = _goals.fold(0.0, (sum, g) => sum + g.saved);
    final totalProgress = totalTarget <= 0 ? 0.0 : (totalSaved / totalTarget).clamp(0.0, 1.0) as double;
    final completed = _goals.where((g) => g.saved >= g.target).toList();
    final inProgress = _goals.where((g) => g.saved < g.target).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
            : Column(
                children: [
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: const Icon(Icons.savings_rounded, color: AppTheme.slate700, size: 20),
                        ),
                        const Expanded(
                          child: Text(
                            'Goals',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slate900),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showForm(null),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: AppTheme.emeraldGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Summary Card ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _GoalsSummaryCard(
                      totalSaved: totalSaved,
                      totalTarget: totalTarget,
                      totalProgress: totalProgress,
                      goalCount: _goals.length,
                      completedCount: completed.length,
                      fmt: fmt,
                    ),
                  ),
                  // ── List ──
                  Expanded(
                    child: _goals.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.emoji_events_outlined, size: 56, color: AppTheme.slate300),
                                const SizedBox(height: 12),
                                const Text('No savings goals yet',
                                    style: TextStyle(color: AppTheme.slate500, fontSize: 15)),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () => _showForm(null),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.emeraldGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('Add your first goal',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                              children: [
                                if (inProgress.isNotEmpty)
                                  _GoalsSection(
                                    label: 'In Progress',
                                    goals: inProgress,
                                    emojiFor: _emojiForGoal,
                                    fmt: fmt,
                                    onTap: _showForm,
                                  ),
                                if (completed.isNotEmpty)
                                  _GoalsSection(
                                    label: 'Completed',
                                    goals: completed,
                                    emojiFor: _emojiForGoal,
                                    fmt: fmt,
                                    onTap: _showForm,
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Components
// ─────────────────────────────────────────────────────────────────────────────

/// Summary card — dark gradient, total saved vs target, overall progress bar.
class _GoalsSummaryCard extends StatelessWidget {
  final double totalSaved;
  final double totalTarget;
  final double totalProgress;
  final int goalCount;
  final int completedCount;
  final NumberFormat fmt;

  const _GoalsSummaryCard({
    required this.totalSaved,
    required this.totalTarget,
    required this.totalProgress,
    required this.goalCount,
    required this.completedCount,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = totalTarget - totalSaved;

    return Container(
      padding: const EdgeInsets.all(18),
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
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Savings Goals',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('Track your financial targets',
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$goalCount goals',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Total Saved', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt.format(totalSaved),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/ ${fmt.format(totalTarget)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalProgress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'Remaining',
                  amount: fmt.format(remaining.clamp(0, double.infinity)),
                  icon: Icons.flag_rounded,
                  color: const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Completed',
                  amount: '$completedCount / $goalCount',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF34D399),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;
  const _StatPill({required this.label, required this.amount, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                Text(amount,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Section — label header + white card containing _GoalItem rows.
class _GoalsSection extends StatelessWidget {
  final String label;
  final List<SavingsGoal> goals;
  final String Function(String) emojiFor;
  final NumberFormat fmt;
  final void Function(SavingsGoal) onTap;

  const _GoalsSection({
    required this.label,
    required this.goals,
    required this.emojiFor,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.slate600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: goals.asMap().entries.map((e) {
              final isLast = e.key == goals.length - 1;
              return _GoalItem(
                goal: e.value,
                emoji: emojiFor(e.value.name),
                fmt: fmt,
                showDivider: !isLast,
                onTap: () => onTap(e.value),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Single goal row: emoji circle | name + saved/target | progress bar + % badge.
class _GoalItem extends StatelessWidget {
  final SavingsGoal goal;
  final String emoji;
  final NumberFormat fmt;
  final bool showDivider;
  final VoidCallback onTap;

  const _GoalItem({
    required this.goal,
    required this.emoji,
    required this.fmt,
    required this.showDivider,
    required this.onTap,
  });

  static Color _colorForGoal(String name) {
    final n = name.toLowerCase();
    if (n.contains('emergency') || n.contains('fund')) return const Color(0xFF3B82F6);
    if (n.contains('car')) return const Color(0xFF6366F1);
    if (n.contains('vacation') || n.contains('travel')) return const Color(0xFF0EA5E9);
    if (n.contains('home') || n.contains('house')) return const Color(0xFFF59E0B);
    if (n.contains('wedding')) return const Color(0xFFEC4899);
    if (n.contains('education') || n.contains('school')) return const Color(0xFF7C3AED);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final progress = goal.target <= 0 ? 0.0 : (goal.saved / goal.target).clamp(0.0, 1.0) as double;
    final isComplete = goal.saved >= goal.target;
    final color = isComplete ? const Color(0xFF10B981) : _colorForGoal(goal.name);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                // Emoji circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + amounts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slate900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${fmt.format(goal.saved)} / ${fmt.format(goal.target)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.slate400),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // % badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isComplete ? '✓ Done' : '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppTheme.slate100,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 56),
                child: Divider(height: 1, color: AppTheme.slate100),
              ),
          ],
        ),
      ),
    );
  }
}

