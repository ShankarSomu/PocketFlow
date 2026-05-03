import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/haptic_feedback.dart';
import '../../db/database.dart';
import '../../models/account.dart';
import '../../models/recurring_transaction.dart';
import '../../models/savings_goal.dart'; // Contains Goal
import '../../services/refresh_notifier.dart';
import '../../services/time_filter.dart';
import '../../widgets/empty_states.dart';
import '../../widgets/error_state_widget.dart';
import '../shared/shared.dart';
import 'components/recurring_form.dart';
import 'components/recurring_item_tile.dart';
import 'components/recurring_summary_card.dart';

export 'components/recurring_history_sheet.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  bool _loading = true;
  String? _error;
  List<RecurringTransaction> _items = [];
  List<Account> _accounts = [];
  List<Goal> _goals = [];

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load recurring transactions: $e';
        _loading = false;
      });
    }
  }

  void _openForm([RecurringTransaction? existing]) {
    showRecurringForm(
      context,
      existing: existing,
      accounts: _accounts,
      goals: _goals,
    );
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
      startDate: item.startDate,
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            if (_loading)
              Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
            else if (_error != null)
              ErrorStateWidget(message: _error, onRetry: _load)
            else
              Column(
                children: [
                  const ScreenHeader(
                    'Recurring',
                    icon: Icons.repeat_rounded,
                    subtitle: 'Monthly commitments',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: RecurringSummaryCard(
                      activeItems: activeItems,
                      pausedCount: pausedItems.length,
                      fmt: fmt,
                    ),
                  ),
                  Expanded(
                    child: _items.isEmpty
                        ? EmptyStates.recurring(context, onAdd: () async {
                            await HapticFeedbackHelper.lightImpact();
                            _openForm();
                          })
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
                                    onEdit: _openForm,
                                    onToggle: _toggleActive,
                                  ),
                                if (pausedItems.isNotEmpty)
                                  _RecurringSection(
                                    label: 'Paused',
                                    items: pausedItems,
                                    accounts: _accounts,
                                    goals: _goals,
                                    fmt: fmt,
                                    onEdit: _openForm,
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
              bottom: MediaQuery.of(context).padding.bottom + 16,
              right: 16,
              child: SpeedDialFab(
                actions: [
                  SpeedDialAction(
                    icon: Icons.add,
                    label: 'Add Recurring',
                    onPressed: _openForm,
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

// ─────────────────────────────────────────────────────────────────────────────
// Section widget
// ─────────────────────────────────────────────────────────────────────────────

class _RecurringSection extends StatelessWidget {
  const _RecurringSection({
    required this.label,
    required this.items,
    required this.accounts,
    required this.goals,
    required this.fmt,
    required this.onEdit,
    required this.onToggle,
  });

  final String label;
  final List<RecurringTransaction> items;
  final List<Account> accounts;
  final List<Goal> goals;
  final NumberFormat fmt;
  final void Function(RecurringTransaction) onEdit;
  final void Function(RecurringTransaction) onToggle;

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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
              return RecurringItemTile(
                item: e.value,
                accounts: accounts,
                goals: goals,
                fmt: fmt,
                showDivider: e.key < items.length - 1,
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

