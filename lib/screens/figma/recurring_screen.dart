import '../../services/time_filter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../models/account.dart';
import '../../models/recurring_transaction.dart';
import '../../models/savings_goal.dart';
import '../../services/refresh_notifier.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import 'shared.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  bool _loading = true;
  List<RecurringTransaction> _items = [];
  List<Account> _accounts = [];
  List<SavingsGoal> _goals = [];

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
    final items = await AppDatabase.getRecurring();
    final accounts = await AppDatabase.getAccounts();
    final goals = await AppDatabase.getGoals();
    if (!mounted) return;
    setState(() {
      _items = items;
      _accounts = accounts;
      _goals = goals;
      _loading = false;
    });
  }

  void _showForm([RecurringTransaction? existing]) {
    String type = existing?.type ?? 'expense';
    int? accountId = existing?.accountId;
    int? toAccountId = existing?.toAccountId;
    int? goalId = existing?.goalId;
    String frequency = existing?.frequency ?? 'monthly';
    final DateTime nextDue = existing?.nextDueDate ?? DateTime.now();
    final amtCtrl = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(2) : '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
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
                Text(existing == null ? 'Add Recurring Item' : 'Edit Recurring Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'expense', label: Text('Expense')),
                      ButtonSegment(value: 'income', label: Text('Income')),
                      ButtonSegment(value: 'transfer', label: Text('Transfer')),
                      ButtonSegment(value: 'goal', label: Text('Goal')),
                    ],
                    selected: {type},
                    onSelectionChanged: (v) => setLocal(() {
                      type = v.first;
                      toAccountId = null;
                      goalId = null;
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                if (type != 'transfer' && type != 'goal') ...[
                  TextField(
                    controller: catCtrl,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                if (type == 'transfer') ...[
                  DropdownButtonFormField<int?>(
                    value: accountId,
                    decoration: const InputDecoration(labelText: 'From Account', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select account')),
                      ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => accountId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: toAccountId,
                    decoration: const InputDecoration(labelText: 'To Account', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select account')),
                      ..._accounts.where((a) => a.id != accountId).map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => toAccountId = v),
                  ),
                  const SizedBox(height: 12),
                ],
                if (type == 'goal') ...[
                  DropdownButtonFormField<int?>(
                    value: goalId,
                    decoration: const InputDecoration(labelText: 'Savings Goal', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select goal')),
                      ..._goals.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
                    ],
                    onChanged: (v) => setLocal(() => goalId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: accountId,
                    decoration: const InputDecoration(labelText: 'Deduct from Account (optional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No account deduction')),
                      ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => accountId = v),
                  ),
                  const SizedBox(height: 12),
                ],
                if ((type == 'income' || type == 'expense') && _accounts.isNotEmpty) ...[
                  DropdownButtonFormField<int?>(
                    value: accountId,
                    decoration: const InputDecoration(labelText: 'Account (optional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No account')),
                      ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setLocal(() => accountId = v),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
                  items: RecurringTransaction.frequencies
                      .map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1))))
                      .toList(),
                  onChanged: (v) => setLocal(() => frequency = v ?? frequency),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (existing != null)
                    TextButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: Text('Delete recurring item?'),
                            content: Text('This will remove the recurring entry permanently.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel')),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await AppDatabase.deleteRecurring(existing.id!);
                        notifyDataChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amtCtrl.text);
                      final category = catCtrl.text.trim();
                      if (amount == null || amount <= 0) return;
                      if (type == 'transfer' && (accountId == null || toAccountId == null)) return;
                      if (type == 'goal' && goalId == null) return;
                      if ((type != 'transfer' && type != 'goal') && category.isEmpty) return;
                      final resolvedCategory = type == 'transfer'
                          ? 'Transfer'
                          : type == 'goal'
                              ? (existing?.category ?? 'Goal contribution')
                              : category;
                      final item = RecurringTransaction(
                        id: existing?.id,
                        type: type,
                        amount: amount,
                        category: resolvedCategory,
                        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                        accountId: accountId,
                        toAccountId: toAccountId,
                        goalId: goalId,
                        frequency: frequency,
                        nextDueDate: nextDue,
                        isActive: existing?.isActive ?? true,
                      );
                      if (existing == null) {
                        await AppDatabase.insertRecurring(item);
                      } else {
                        await AppDatabase.updateRecurring(item);
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

  String _emojiForCategory(String category, bool isActive) {
    if (!isActive) return '??';
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('dining') || cat.contains('restaurant')) return '??';
    if (cat.contains('transport') || cat.contains('car') || cat.contains('gas')) return '??';
    if (cat.contains('shopping')) return '???';
    if (cat.contains('entertainment') || cat.contains('subscription') || cat.contains('streaming')) return '??';
    if (cat.contains('utilities') || cat.contains('electric') || cat.contains('water') || cat.contains('internet')) return '?';
    if (cat.contains('health') || cat.contains('gym') || cat.contains('fitness')) return '??';
    if (cat.contains('home') || cat.contains('rent') || cat.contains('mortgage')) return '??';
    if (cat.contains('education')) return '??';
    if (cat.contains('insurance')) return '???';
    if (cat.contains('transfer')) return '??';
    if (cat.contains('goal') || cat.contains('saving')) return '??';
    if (cat.contains('income') || cat.contains('salary')) return '??';
    return '??';
  }

  void _toggleActive(RecurringTransaction item) {
    final updated = RecurringTransaction(
      id: item.id,
      type: item.type,
      amount: item.amount,
      category: item.category,
      note: item.note,
      accountId: item.accountId,
      toAccountId: item.toAccountId,
      goalId: item.goalId,
      frequency: item.frequency,
      nextDueDate: item.nextDueDate,
      isActive: !item.isActive,
    );
    AppDatabase.updateRecurring(updated).then((_) => notifyDataChanged());
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final activeItems = _items.where((i) => i.isActive).toList();
    final pausedItems = _items.where((i) => !i.isActive).toList();
    final totalMonthly = activeItems.fold(0.0, (s, i) => s + i.amount);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            _loading
                ? Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : Column(
                children: [
                  const ScreenHeader('Recurring'),
                  // -- Summary Card --
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _RecurringSummaryCard(
                      totalMonthly: totalMonthly,
                      activeCount: activeItems.length,
                      pausedCount: pausedItems.length,
                      fmt: fmt,
                    ),
                  ),
                  // -- List --
                  Expanded(
                    child: _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.repeat_rounded, size: 56, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                                const SizedBox(height: 12),
                                Text('No recurring items yet',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 15)),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () => _showForm(null),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: ThemeService.instance.cardGradient,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: ThemeService.instance.primaryShadow,
                                    ),
                                    child: Text('Add your first', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                              children: [
                                if (activeItems.isNotEmpty)
                                  _RecurringSection(
                                    label: 'Active',
                                    items: activeItems,
                                    accounts: _accounts,
                                    goals: _goals,
                                    fmt: fmt,
                                    emojiFor: _emojiForCategory,
                                    onEdit: _showForm,
                                    onToggle: _toggleActive,
                                  ),
                                if (pausedItems.isNotEmpty)
                                  _RecurringSection(
                                    label: 'Paused',
                                    items: pausedItems,
                                    accounts: _accounts,
                                    goals: _goals,
                                    fmt: fmt,
                                    emojiFor: _emojiForCategory,
                                    onEdit: _showForm,
                                    onToggle: _toggleActive,
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
              bottom: 16,
              right: 16,
              child: SpeedDialFab(
                actions: [
                  SpeedDialAction(
                    icon: Icons.add,
                    label: 'Add Recurring',
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

/// Summary card � dark gradient, total monthly + active/paused counts.
class _RecurringSummaryCard extends StatelessWidget {
  final double totalMonthly;
  final int activeCount;
  final int pausedCount;
  final NumberFormat fmt;

  const _RecurringSummaryCard({
    required this.totalMonthly,
    required this.activeCount,
    required this.pausedCount,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ThemeService.instance.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ThemeService.instance.primaryShadow,
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
                child: Icon(Icons.repeat_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recurring Schedule',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('Monthly commitments',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Total / month', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(fmt.format(totalMonthly),
              style: TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'Active',
                  value: '$activeCount',
                  icon: Icons.play_circle_rounded,
                  color: const Color(0xFF34D399),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Paused',
                  value: '$pausedCount',
                  icon: Icons.pause_circle_rounded,
                  color: const Color(0xFFFBBF24),
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
  final String value;
  final IconData icon;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.icon, required this.color});

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
              Text(value,
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

/// Section � label header + white card containing _RecurringItem rows.
class _RecurringSection extends StatelessWidget {
  final String label;
  final List<RecurringTransaction> items;
  final List<Account> accounts;
  final List<SavingsGoal> goals;
  final NumberFormat fmt;
  final String Function(String, bool) emojiFor;
  final void Function(RecurringTransaction) onEdit;
  final void Function(RecurringTransaction) onToggle;

  const _RecurringSection({
    required this.label,
    required this.items,
    required this.accounts,
    required this.goals,
    required this.fmt,
    required this.emojiFor,
    required this.onEdit,
    required this.onToggle,
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
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return _RecurringItem(
                item: e.value,
                accounts: accounts,
                goals: goals,
                fmt: fmt,
                emoji: emojiFor(e.value.category, e.value.isActive),
                showDivider: !isLast,
                onEdit: () => onEdit(e.value),
                onToggle: () => onToggle(e.value),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------

/// Single recurring row: icon circle | title + frequency+due | amount | actions.
class _RecurringItem extends StatelessWidget {
  final RecurringTransaction item;
  final List<Account> accounts;
  final List<SavingsGoal> goals;
  final NumberFormat fmt;
  final String emoji;
  final bool showDivider;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _RecurringItem({
    required this.item,
    required this.accounts,
    required this.goals,
    required this.fmt,
    required this.emoji,
    required this.showDivider,
    required this.onEdit,
    required this.onToggle,
  });

  static Color _colorForType(String type) {
    switch (type) {
      case 'income': return const Color(0xFF10B981);
      case 'transfer': return const Color(0xFF3B82F6);
      case 'goal': return const Color(0xFFF59E0B);
      default: return const Color(0xFF6366F1);
    }
  }

  static IconData _iconForType(String type, String category) {
    if (type == 'income') return Icons.arrow_downward_rounded;
    if (type == 'transfer') return Icons.swap_horiz_rounded;
    if (type == 'goal') return Icons.savings_rounded;
    final c = category.toLowerCase();
    if (c.contains('netflix') || c.contains('tv') || c.contains('streaming')) return Icons.subscriptions_rounded;
    if (c.contains('spotify') || c.contains('music')) return Icons.music_note_rounded;
    if (c.contains('gym') || c.contains('fitness')) return Icons.fitness_center_rounded;
    if (c.contains('phone') || c.contains('mobile')) return Icons.phone_android_rounded;
    if (c.contains('internet') || c.contains('wifi')) return Icons.wifi_rounded;
    if (c.contains('insurance')) return Icons.shield_rounded;
    if (c.contains('food') || c.contains('dining')) return Icons.restaurant_rounded;
    if (c.contains('rent') || c.contains('mortgage')) return Icons.home_rounded;
    return Icons.repeat_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(item.type);
    final icon = _iconForType(item.type, item.category);
    final account = accounts.where((a) => a.id == item.accountId).firstOrNull;
    final dueStr = DateFormat('MMM d').format(item.nextDueDate);
    final freq = item.frequency[0].toUpperCase() + item.frequency.substring(1);

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                // Icon circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(item.isActive ? 0.12 : 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: item.isActive ? color : Theme.of(context).colorScheme.onSurface.withOpacity(0.4), size: 20),
                ),
                const SizedBox(width: 12),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: item.isActive ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$freq Next $dueStr${account != null ? '  ${account.name}' : ''}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Amount + pause/resume toggle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.type == 'income' ? '+' : '-'}${fmt.format(item.amount)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: item.isActive
                            ? (item.type == 'income' ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onToggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.isActive
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.isActive ? 'Pause' : 'Resume',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: item.isActive
                                ? Theme.of(context).colorScheme.onSecondaryContainer
                                : Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (item.note != null && item.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Text(
                    item.note!,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
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

