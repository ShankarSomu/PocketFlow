import '../../services/time_filter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../models/account.dart';
import '../../models/savings_goal.dart';
import '../../services/refresh_notifier.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_state_widget.dart';
import '../../widgets/empty_states.dart';
import '../../core/haptic_feedback.dart';
import '../shared/shared.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  bool _loading = true;
  String? _error;
  List<SavingsGoal> _goals = [];
  List<Account> _accounts = [];
  Map<int, double> _accountBalances = {};

  @override
  void initState() {
    super.initState();
    _load();
    appRefresh.addListener(_load);
    appTimeFilter.addListener(_load);
  }

  @override
  void dispose() {
    appRefresh.removeListener(_load);
    appTimeFilter.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load savings goals: $e';
        _loading = false;
      });
    }
  }

  void _showForm([SavingsGoal? existing]) {
    int? accountId = existing?.accountId;
    int priority = existing?.priority ?? 5;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final targetCtrl = TextEditingController(text: existing != null ? existing.target.toStringAsFixed(2) : '');
    final savedCtrl = TextEditingController(text: existing != null ? existing.saved.toStringAsFixed(2) : '');
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
                Text(existing == null ? 'New Goal' : 'Edit Goal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (\$${_accountBalances[a.id]?.toStringAsFixed(0) ?? '0'})'))),
                  ],
                  onChanged: (v) => setLocal(() => accountId = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Text('Priority: ', style: TextStyle(fontSize: 14)),
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
                    child: Text('$priority', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            title: Text('Delete Goal?'),
                            content: Text('Delete "${existing.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel')),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await HapticFeedbackHelper.heavyImpact();
                        await AppDatabase.deleteGoal(existing.id!);
                        notifyDataChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                      label: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
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

  IconData _iconForGoal(String name) {
    final n = name.toLowerCase();
    if (n.contains('car')) return Icons.directions_car_rounded;
    if (n.contains('home') || n.contains('house')) return Icons.home_rounded;
    if (n.contains('vacation') || n.contains('travel') || n.contains('trip')) return Icons.flight_rounded;
    if (n.contains('education') || n.contains('school') || n.contains('college')) return Icons.school_rounded;
    if (n.contains('phone') || n.contains('tech') || n.contains('laptop') || n.contains('computer')) return Icons.devices_rounded;
    if (n.contains('wedding') || n.contains('ring')) return Icons.favorite_rounded;
    if (n.contains('emergency') || n.contains('fund')) return Icons.shield_rounded;
    if (n.contains('retire')) return Icons.beach_access_rounded;
    if (n.contains('baby') || n.contains('child')) return Icons.child_care_rounded;
    return Icons.savings_rounded;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            _loading
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                : _error != null
                    ? ErrorStateWidget(
                        message: _error!,
                        onRetry: _load,
                      )
                    : Column(
                children: [
                  const ScreenHeader(
                    'Goals',
                    icon: Icons.emoji_events_rounded,
                    subtitle: 'Track your financial targets',
                  ),
                  // -- Summary Card --
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
                  // -- List --
                  Expanded(
                    child: _goals.isEmpty
                        ? EmptyStates.savingsGoals(context, onAdd: () async {
                            await HapticFeedbackHelper.lightImpact();
                            _showForm(null);
                          })
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                              children: [
                                if (inProgress.isNotEmpty)
                                  _GoalsSection(
                                    label: 'In Progress',
                                    goals: inProgress,
                                    iconFor: _iconForGoal,
                                    fmt: fmt,
                                    onTap: _showForm,
                                  ),
                                if (completed.isNotEmpty)
                                  _GoalsSection(
                                    label: 'Completed',
                                    goals: completed,
                                    iconFor: _iconForGoal,
                                    fmt: fmt,
                                    onTap: _showForm,
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            const Positioned(
              bottom: 16,
              left: 16,
              child: CalendarFab(),
            ),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              right: 16,
              child: SpeedDialFab(
                actions: [
                  SpeedDialAction(
                    icon: Icons.add,
                    label: 'Add Goal',
                    onPressed: () => _showForm(null),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Reusable Components
// -----------------------------------------------------------------------------

/// Summary card � dark gradient, total saved vs target, overall progress bar.
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
        gradient: ThemeService.instance.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Saved', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$goalCount goals',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt.format(totalSaved),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/ ${fmt.format(totalTarget)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8), fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2), width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: totalProgress,
                minHeight: 8,
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).brightness == Brightness.dark
                    ? Colors.greenAccent
                    : Theme.of(context).colorScheme.tertiary
                ),
              ),
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
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Completed',
                  amount: '$completedCount / $goalCount',
                  icon: Icons.check_circle_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
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
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
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
                Text(label, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(amount,
                    style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

/// Section � label header + white card containing _GoalItem rows.
class _GoalsSection extends StatelessWidget {
  final String label;
  final List<SavingsGoal> goals;
  final IconData Function(String) iconFor;
  final NumberFormat fmt;
  final void Function(SavingsGoal) onTap;

  const _GoalsSection({
    required this.label,
    required this.goals,
    required this.iconFor,
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: goals.asMap().entries.map((e) {
              final isLast = e.key == goals.length - 1;
              return _GoalItem(
                goal: e.value,
                icon: iconFor(e.value.name),
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

// -----------------------------------------------------------------------------

/// Single goal row: icon circle | name + saved/target | progress bar + % badge.
class _GoalItem extends StatelessWidget {
  final SavingsGoal goal;
  final IconData icon;
  final NumberFormat fmt;
  final bool showDivider;
  final VoidCallback onTap;

  const _GoalItem({
    required this.goal,
    required this.icon,
    required this.fmt,
    required this.showDivider,
    required this.onTap,
  });

  static Color _colorForGoal(BuildContext context, String name) {
    final colorScheme = Theme.of(context).colorScheme;
    final n = name.toLowerCase();
    if (n.contains('emergency') || n.contains('fund')) return colorScheme.primary;
    if (n.contains('car')) return colorScheme.primary.withOpacity(0.7);
    if (n.contains('vacation') || n.contains('travel')) return colorScheme.primary;
    if (n.contains('home') || n.contains('house')) return colorScheme.secondary;
    if (n.contains('wedding')) return colorScheme.error.withOpacity(0.7);
    if (n.contains('education') || n.contains('school')) return colorScheme.primary.withOpacity(0.6);
    return colorScheme.tertiary;
  }

  @override
  Widget build(BuildContext context) {
    final progress = goal.target <= 0 ? 0.0 : (goal.saved / goal.target).clamp(0.0, 1.0) as double;
    final isComplete = goal.saved >= goal.target;
    final color = isComplete ? Theme.of(context).colorScheme.tertiary : _colorForGoal(context, goal.name);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                // Icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
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
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${fmt.format(goal.saved)} / ${fmt.format(goal.target)}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
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
                    isComplete ? 'Done' : '${(progress * 100).toStringAsFixed(0)}%',
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
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3), width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 56),
                child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
              ),
          ],
        ),
      ),
    );
  }
}

